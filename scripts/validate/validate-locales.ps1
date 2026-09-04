<#
.SYNOPSIS
    Validates Epithet locale files for key parity, source coverage, and WoW
    Lua 5.1 compatibility.

.DESCRIPTION
    enGB.lua is the reference (base / default) locale. Every other locale in
    Locales\ overlays onto it, so a missing key is not fatal (it falls back to
    English at runtime) but IS reported so translators know what is outstanding.

    Checks performed:
      1. Missing keys   - keys in enGB not present in another locale (warning).
      2. Orphan keys    - keys in another locale not present in enGB (error:
                          almost always a typo or a stale key).
      3. Hex escapes    - "\xNN" byte escapes, which WoW's Lua 5.1 does NOT
                          support (error). Use decimal escapes, e.g. \226\128\148.
      4. Undefined keys - keys the addon source looks up that no locale defines
                          (error). ns.L falls back to the key NAME when nothing
                          defines it, so these render in-game as raw text like
                          "SOCIAL_LAYOUT_PORTRAIT_MODE". Checks 1 and 2 cannot
                          catch this: every overlay can sit at 100% coverage
                          while the base itself is missing a key the UI asks for.
      5. Unused keys    - keys enGB defines that no source file appears to
                          reference (warning - stale leftovers to prune).

    Source scanning (checks 4 and 5) is static and therefore approximate. Two
    reference forms are recognised, and they feed different checks:
      * direct lookups   - L["KEY"] / ns.L["KEY"]. Unambiguous, so these alone
                           drive the check 4 ERROR.
      * indirect lookups - a bare "SCREAMING_SNAKE" string literal stashed in a
                           table or field and resolved later as L[key], e.g.
                           labelKey = "SOCIAL_LAYOUT_PORTRAIT", or the
                           KIND_LABEL_KEYS / SHOUT_FORMAT_KEYS / LANGUAGE_NAME_KEYS
                           tables. Indistinguishable from any other uppercase
                           literal ("TOPLEFT", "PLAYER_TARGET_CHANGED", ...), so
                           these only ever SUPPRESS a check 5 warning - they are
                           never treated as errors or as proof of a reference.
    Keys built by concatenation (L["CAT_" .. code]) cannot be seen statically at
    all, so their prefixes are listed in -DynamicKeyPrefixes and excluded from
    the unused-key warning.

    Exit code is non-zero when any ERROR-level problem is found, so this can gate
    CI. Missing-key and unused-key warnings alone do not fail the run.

.EXAMPLE
    pwsh scripts\validate\validate-locales.ps1
#>

[CmdletBinding()]
param(
    [string]$RepoRoot = (Join-Path $PSScriptRoot '..\..'),
    [string]$LocalesDir = (Join-Path $PSScriptRoot '..\..\Locales'),
    [string]$ReferenceLocale = 'enGB',

    # Addon source scanned for locale-key references (checks 4 and 5). Paths are
    # relative to -RepoRoot; missing ones are skipped. libs\ and data\ are
    # deliberately excluded - neither uses ns.L.
    [string[]]$SourceDirs = @('Core', 'UI', 'Spotting', 'WhatsNew'),

    # Extra source files outside -SourceDirs that reference locale keys.
    [string[]]$SourceFiles = @('Locales\LocaleManager.lua'),

    # Key families assembled at runtime by concatenation, which a static scan can
    # never see. Anything starting with one of these is exempt from the unused-key
    # warning (check 5). Each entry names its construction site.
    [string[]]$DynamicKeyPrefixes = @(
        'SPOT_ACHV_NAME_',  # Spotting\Achievements.lua - "SPOT_ACHV_NAME_" .. id:upper()
        'SPOT_ACHV_DESC_',  # Spotting\Achievements.lua - "SPOT_ACHV_DESC_" .. id:upper()
        'CAT_',             # Core\TitleData.lua        - "CAT_" .. code:upper()
        'EXPANSION_',       # Core\TitleData.lua        - "EXPANSION_" .. code:upper()
        'AVAILABILITY_',    # UI\Detail.lua             - "AVAILABILITY_" .. availability:upper()
        'MONTH_'            # Core\TitleData.lua, Spotting\LogbookUI.lua - "MONTH_" .. month
    )
)

$ErrorActionPreference = 'Stop'

function Get-LocaleKeys {
    param([string]$Path)
    $keys = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($line in Get-Content -LiteralPath $Path) {
        # Match: L["SOME_KEY"] =
        $m = [regex]::Match($line, '^\s*L\["([^"]+)"\]\s*=')
        if ($m.Success) { [void]$keys.Add($m.Groups[1].Value) }
    }
    return $keys
}

function Get-HexEscapeHits {
    param([string]$Path)
    $hits = @()
    $n = 0
    foreach ($line in Get-Content -LiteralPath $Path) {
        $n++
        if ($line -match '\\x[0-9A-Fa-f]') { $hits += "  line ${n}: $($line.Trim())" }
    }
    return $hits
}

# Scan the addon source for locale-key references. Returns two views, because
# they are trusted differently:
#   .Direct - L["KEY"] lookups, mapped to the first file:line seen, so an
#             undefined key can be reported where it is used. Drives check 4.
#   .Any    - .Direct plus every bare uppercase string literal. Far too broad to
#             prove anything (it catches "TOPLEFT", event names, race tokens),
#             but exactly right for silencing check 5 on keys held in a table
#             and resolved later as L[key].
function Get-SourceKeyReferences {
    param([string[]]$Paths, [string]$Root)
    $direct = @{}
    $any = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($path in $Paths) {
        $rel = $path
        if ($Root -and $path.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)) {
            $rel = $path.Substring($Root.Length).TrimStart([char]92, [char]47)
        }
        $n = 0
        foreach ($line in Get-Content -LiteralPath $path) {
            $n++
            foreach ($m in [regex]::Matches($line, '\bL\["([A-Za-z0-9_]+)"\]')) {
                $k = $m.Groups[1].Value
                if (-not $direct.ContainsKey($k)) { $direct[$k] = "${rel}:${n}" }
                [void]$any.Add($k)
            }
            foreach ($m in [regex]::Matches($line, '"([A-Z][A-Z0-9_]*[A-Z0-9])"')) {
                [void]$any.Add($m.Groups[1].Value)
            }
        }
    }
    return [pscustomobject]@{ Direct = $direct; Any = $any }
}

$refPath = Join-Path $LocalesDir "$ReferenceLocale.lua"
if (-not (Test-Path -LiteralPath $refPath)) {
    Write-Error "Reference locale not found: $refPath"
    exit 2
}

$refKeys = Get-LocaleKeys -Path $refPath
Write-Host "Reference locale $ReferenceLocale : $($refKeys.Count) keys" -ForegroundColor Cyan

$errors = 0
$localeFiles = Get-ChildItem -LiteralPath $LocalesDir -Filter '*.lua'

foreach ($file in $localeFiles) {
    $locale = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    Write-Host ""
    Write-Host "== $locale ==" -ForegroundColor White

    # Hex-escape lint (all locales, including the reference).
    $hex = Get-HexEscapeHits -Path $file.FullName
    if ($hex.Count -gt 0) {
        Write-Host "  ERROR: \xNN hex escapes are not supported by WoW Lua 5.1:" -ForegroundColor Red
        $hex | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        $errors += $hex.Count
    }

    if ($locale -eq $ReferenceLocale) { continue }

    # Only files named like a locale code (e.g. enGB, ruRU, deDE) are locale data.
    # Others in this folder (e.g. LocaleManager.lua) are machinery — hex-linted
    # above, but not parity-checked.
    if ($locale -notmatch '^[a-z]{2}[A-Z]{2}$') { continue }

    $keys = Get-LocaleKeys -Path $file.FullName

    $missing = @($refKeys | Where-Object { -not $keys.Contains($_) } | Sort-Object)
    $orphan  = @($keys    | Where-Object { -not $refKeys.Contains($_) } | Sort-Object)

    $translated = $refKeys.Count - $missing.Count
    $pct = if ($refKeys.Count -gt 0) { [math]::Round(100 * $translated / $refKeys.Count, 1) } else { 100 }
    Write-Host "  Coverage: $translated / $($refKeys.Count) keys ($pct`%)" -ForegroundColor Green

    if ($missing.Count -gt 0) {
        Write-Host "  WARNING: $($missing.Count) untranslated key(s) (will fall back to English):" -ForegroundColor Yellow
        $missing | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
    }

    if ($orphan.Count -gt 0) {
        Write-Host "  ERROR: $($orphan.Count) orphan key(s) not present in ${ReferenceLocale} (typo or stale?):" -ForegroundColor Red
        $orphan | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
        $errors += $orphan.Count
    }
}

# --- Checks 4 and 5: the base locale versus what the addon source actually uses.
$root = (Resolve-Path -LiteralPath $RepoRoot).Path
$sourcePaths = @()
foreach ($dir in $SourceDirs) {
    $full = Join-Path $root $dir
    if (Test-Path -LiteralPath $full) {
        $sourcePaths += @(Get-ChildItem -LiteralPath $full -Recurse -Include '*.lua', '*.xml' -File | ForEach-Object { $_.FullName })
    }
}
foreach ($rel in $SourceFiles) {
    $full = Join-Path $root $rel
    if (Test-Path -LiteralPath $full) { $sourcePaths += (Resolve-Path -LiteralPath $full).Path }
}

Write-Host ""
Write-Host "== source usage ==" -ForegroundColor White

if ($sourcePaths.Count -eq 0) {
    Write-Host "  WARNING: no source files found under $root - skipping usage checks." -ForegroundColor Yellow
} else {
    $refs = Get-SourceKeyReferences -Paths $sourcePaths -Root $root
    Write-Host "  Scanned $($sourcePaths.Count) source file(s)." -ForegroundColor Green

    # 4. Looked up by the addon but defined nowhere: renders as the raw key name.
    # Direct L["KEY"] lookups only - a bare literal is not evidence of a lookup.
    $undefined = @($refs.Direct.Keys | Where-Object { -not $refKeys.Contains($_) } | Sort-Object)
    if ($undefined.Count -gt 0) {
        Write-Host "  ERROR: $($undefined.Count) key(s) used in source but missing from ${ReferenceLocale} (will show the raw key in-game):" -ForegroundColor Red
        $undefined | ForEach-Object { Write-Host "    - $_  ($($refs.Direct[$_]))" -ForegroundColor Red }
        $errors += $undefined.Count
    }

    # 5. Defined but seemingly unreferenced: stale leftovers. Warning only, since
    # a static scan cannot prove a key is dead.
    $unused = @($refKeys | Where-Object {
        if ($refs.Any.Contains($_)) { return $false }
        $key = $_
        foreach ($prefix in $DynamicKeyPrefixes) {
            if ($key.StartsWith($prefix, [System.StringComparison]::Ordinal)) { return $false }
        }
        return $true
    } | Sort-Object)

    if ($unused.Count -gt 0) {
        Write-Host "  WARNING: $($unused.Count) key(s) defined in ${ReferenceLocale} but not referenced by any source file:" -ForegroundColor Yellow
        $unused | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
        Write-Host "    (Stale? Delete it from every locale. If it is built at runtime, add its prefix to -DynamicKeyPrefixes.)" -ForegroundColor Yellow
    }
}

Write-Host ""
if ($errors -gt 0) {
    Write-Host "FAILED: $errors error(s) found." -ForegroundColor Red
    exit 1
}
Write-Host "OK: no errors. (Untranslated and unused keys, if any, are warnings only.)" -ForegroundColor Green
exit 0
