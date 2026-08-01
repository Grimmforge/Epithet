<#
.SYNOPSIS
    Validates Epithet locale files for key parity and WoW Lua 5.1 compatibility.

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

    Exit code is non-zero when any ERROR-level problem is found, so this can gate
    CI. Missing-key warnings alone do not fail the run.

.EXAMPLE
    pwsh scripts\validate\validate-locales.ps1
#>

[CmdletBinding()]
param(
    [string]$LocalesDir = (Join-Path $PSScriptRoot '..\..\Locales'),
    [string]$ReferenceLocale = 'enGB'
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

Write-Host ""
if ($errors -gt 0) {
    Write-Host "FAILED: $errors error(s) found." -ForegroundColor Red
    exit 1
}
Write-Host "OK: no errors. (Untranslated keys, if any, are warnings only.)" -ForegroundColor Green
exit 0
