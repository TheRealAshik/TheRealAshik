#Requires -Version 5.1
<#
.SYNOPSIS
    Remote bootstrap — fetch and run any script in this repo by name.

.DESCRIPTION
    Run the TUI launcher:
        irm https://raw.githubusercontent.com/TheRealAshik/TheRealAshik/main/run.ps1 | iex

    Run a specific script directly (no menu):
        & ([scriptblock]::Create((irm https://raw.githubusercontent.com/TheRealAshik/TheRealAshik/main/run.ps1))) -Script force_delete

.PARAMETER Script
    Name of the script to run (without extension). Omit to open the TUI launcher.

.PARAMETER List
    List all available scripts and exit.

.PARAMETER Branch
    GitHub branch to pull from. Defaults to 'main'.
#>

param(
    [string]$Script = "",
    [switch]$List,
    [string]$Branch = "main"
)

# ── Config ────────────────────────────────────────────────────────────────────
$GITHUB_USER = "TheRealAshik"
$GITHUB_REPO = "TheRealAshik"
$RAW_BASE    = "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$Branch"

# ── Script registry ───────────────────────────────────────────────────────────
# Keep in sync with launcher.ps1
$Registry = @{
    "force_delete" = @{ Path = "scripts/force_delete.ps1"; Desc = "Forcefully delete a locked file or folder (runs as Admin)" }
    # Add entries here as you add scripts:
    # "my_script"  = @{ Path = "scripts/my_script.ps1";    Desc = "Does something cool" }
}

# ── List mode ─────────────────────────────────────────────────────────────────
if ($List) {
    Write-Host ""
    Write-Host "  Available scripts:" -ForegroundColor Cyan
    Write-Host ""
    foreach ($key in ($Registry.Keys | Sort-Object)) {
        Write-Host ("  {0,-20}  {1}" -f $key, $Registry[$key].Desc) -ForegroundColor White
    }
    Write-Host ""
    Write-Host "  Usage:" -ForegroundColor DarkGray
    Write-Host "    & ([scriptblock]::Create((irm $RAW_BASE/run.ps1))) -Script <name>" -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}

# ── No script specified → launch TUI ─────────────────────────────────────────
if ([string]::IsNullOrWhiteSpace($Script)) {
    Write-Host "  Loading launcher..." -ForegroundColor DarkCyan
    try {
        $launcherCode = (New-Object System.Net.WebClient).DownloadString("$RAW_BASE/launcher.ps1")
        Invoke-Expression $launcherCode
    } catch {
        Write-Host "  ERROR: Could not fetch launcher — $_" -ForegroundColor Red
        exit 1
    }
    exit 0
}

# ── Run specific script ───────────────────────────────────────────────────────
$key = $Script.ToLower().Trim()

if (-not $Registry.ContainsKey($key)) {
    Write-Host ""
    Write-Host "  Unknown script: '$Script'" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Available scripts:" -ForegroundColor Yellow
    foreach ($k in ($Registry.Keys | Sort-Object)) {
        Write-Host "    - $k" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "  Tip: Run with -List to see all scripts and descriptions." -ForegroundColor DarkGray
    Write-Host ""
    exit 1
}

$entry = $Registry[$key]
$url   = "$RAW_BASE/$($entry.Path)"

Write-Host ""
Write-Host "  Script : $($entry.Desc)" -ForegroundColor Cyan
Write-Host "  Source : $url" -ForegroundColor DarkGray
Write-Host ""

try {
    $code = (New-Object System.Net.WebClient).DownloadString($url)
} catch {
    Write-Host "  ERROR: Could not fetch script — $_" -ForegroundColor Red
    exit 1
}

Invoke-Expression $code
