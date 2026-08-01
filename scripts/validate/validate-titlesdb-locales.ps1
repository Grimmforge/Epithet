<#
.SYNOPSIS
    Validates localised Title-Database overlays against the enGB base.

.DESCRIPTION
    data/TitlesDB.enGB.lua is the authoritative base (every titleID lives there).
    Localised overlays (data/TitlesDB.<code>.lua) are SPARSE, titleID-keyed tables
    that translate only free-prose fields; any titleID/field they omit falls back
    to the base at runtime, so a missing title is fine and not reported.

    Checks per overlay:
      1. Orphan titleIDs - IDs in an overlay that don't exist in the enGB base
                           (error: a typo or a stale ID that will never apply).
      2. Coverage        - how many base titles the overlay translates (info).
      3. Hex escapes     - "\xNN" byte escapes, unsupported by WoW's Lua 5.1
                           (error). Use decimal escapes, e.g. \226\128\148.

    The ".example" template is intentionally ignored. Exit code is non-zero when
    any ERROR-level problem is found, so this can gate CI.

.EXAMPLE
    powershell -File scripts\validate\validate-titlesdb-locales.ps1
#>

[CmdletBinding()]
param(
    [string]$DataDir = (Join-Path $PSScriptRoot '..\..\data'),
    [string]$BaseLocale = 'enGB'
)

$ErrorActionPreference = 'Stop'

function Get-BaseTitleIDs {
    param([string]$Path)
    $ids = [System.Collections.Generic.HashSet[int]]::new()
    foreach ($line in Get-Content -LiteralPath $Path) {
        foreach ($m in [regex]::Matches($line, 'titleID\s*=\s*(\d+)')) {
            [void]$ids.Add([int]$m.Groups[1].Value)
        }
    }
    return $ids
}

function Get-OverlayTitleIDs {
    param([string]$Path)
    $ids = @()
    foreach ($line in Get-Content -LiteralPath $Path) {
        # Overlay keys look like:  [660] = {
        $m = [regex]::Match($line, '^\s*\[(\d+)\]\s*=')
        if ($m.Success) { $ids += [int]$m.Groups[1].Value }
    }
    return $ids
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

function Get-NullLiteralHits {
    param([string]$Path)
    # Lua has no `null` keyword (that's a JS/JSON-ism); `x = null` silently means
    # `x = nil`, so a title emitted with `titleID = null` loses its ID entirely.
    # Catch it as an error — usually a leak in the upstream generator.
    $hits = @()
    $n = 0
    foreach ($line in Get-Content -LiteralPath $Path) {
        $n++
        if ($line -match '[=,{]\s*null\b') { $hits += "  line ${n}: $($line.Trim())" }
    }
    return $hits
}

$basePath = Join-Path $DataDir "TitlesDB.$BaseLocale.lua"
if (-not (Test-Path -LiteralPath $basePath)) {
    Write-Error "Base title database not found: $basePath"
    exit 2
}

$baseIDs = Get-BaseTitleIDs -Path $basePath
Write-Host "Base $BaseLocale : $($baseIDs.Count) titleIDs" -ForegroundColor Cyan

# Lint the base too (decimal escapes are fine; \x and `null` are not).
$errors = 0
$baseHex = Get-HexEscapeHits -Path $basePath
$baseNull = Get-NullLiteralHits -Path $basePath
if ($baseHex.Count -gt 0 -or $baseNull.Count -gt 0) {
    Write-Host ""
    Write-Host "== $BaseLocale (base) ==" -ForegroundColor White
    if ($baseHex.Count -gt 0) {
        Write-Host "  ERROR: \xNN hex escapes are not supported by WoW Lua 5.1:" -ForegroundColor Red
        $baseHex | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        $errors += $baseHex.Count
    }
    if ($baseNull.Count -gt 0) {
        Write-Host "  ERROR: 'null' is not a Lua value (use nil) - these titles lose their field:" -ForegroundColor Red
        $baseNull | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        $errors += $baseNull.Count
    }
}

# Overlays: data/TitlesDB.<code>.lua where <code> is a locale code and not the base.
$overlays = Get-ChildItem -LiteralPath $DataDir -Filter 'TitlesDB.*.lua' | Where-Object {
    $_.Name -match '^TitlesDB\.([a-z]{2}[A-Z]{2})\.lua$' -and $_.Name -ne "TitlesDB.$BaseLocale.lua"
}

if (-not $overlays -or $overlays.Count -eq 0) {
    Write-Host ""
    Write-Host "No localised overlays present (nothing to check beyond the base)." -ForegroundColor DarkGray
}

foreach ($file in $overlays) {
    $code = [regex]::Match($file.Name, '^TitlesDB\.([a-z]{2}[A-Z]{2})\.lua$').Groups[1].Value
    Write-Host ""
    Write-Host "== $code ==" -ForegroundColor White

    $hex = Get-HexEscapeHits -Path $file.FullName
    if ($hex.Count -gt 0) {
        Write-Host "  ERROR: \xNN hex escapes are not supported by WoW Lua 5.1:" -ForegroundColor Red
        $hex | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        $errors += $hex.Count
    }

    $nullHits = Get-NullLiteralHits -Path $file.FullName
    if ($nullHits.Count -gt 0) {
        Write-Host "  ERROR: 'null' is not a Lua value (use nil):" -ForegroundColor Red
        $nullHits | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        $errors += $nullHits.Count
    }

    $ids = @(Get-OverlayTitleIDs -Path $file.FullName)
    $orphans = @($ids | Where-Object { -not $baseIDs.Contains($_) } | Sort-Object -Unique)
    $translated = ($ids | Sort-Object -Unique | Where-Object { $baseIDs.Contains($_) }).Count

    $pct = if ($baseIDs.Count -gt 0) { [math]::Round(100 * $translated / $baseIDs.Count, 1) } else { 0 }
    Write-Host "  Coverage: $translated / $($baseIDs.Count) titles ($pct`%)" -ForegroundColor Green

    if ($orphans.Count -gt 0) {
        Write-Host "  ERROR: $($orphans.Count) titleID(s) not present in the $BaseLocale base (typo or stale?):" -ForegroundColor Red
        $orphans | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
        $errors += $orphans.Count
    }
}

Write-Host ""
if ($errors -gt 0) {
    Write-Host "FAILED: $errors error(s) found." -ForegroundColor Red
    exit 1
}
Write-Host "OK: no errors." -ForegroundColor Green
exit 0
