#Requires -Version 5.1
<#
.SYNOPSIS
    Interactive TUI launcher for TheRealAshik's GitHub scripts.
    Fetches and runs scripts directly from GitHub — no manual download needed.

.USAGE
    Run from anywhere with:
    irm https://raw.githubusercontent.com/TheRealAshik/TheRealAshik/main/launcher.ps1 | iex
#>

# ── Config ────────────────────────────────────────────────────────────────────
$GITHUB_USER   = "TheRealAshik"
$GITHUB_REPO   = "TheRealAshik"
$GITHUB_BRANCH = "main"
$RAW_BASE      = "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$GITHUB_BRANCH"

# ── Script registry ───────────────────────────────────────────────────────────
# Add new scripts here as you create them.
# Format: @{ Name = "Display name"; Path = "scripts/file.ps1"; Desc = "Short description" }
$Scripts = @(
    @{ Name = "Force Delete";  Path = "scripts/force_delete.ps1"; Desc = "Forcefully delete a locked file or folder (runs as Admin)" }
    # Add more scripts below:
    # @{ Name = "My Script";   Path = "scripts/my_script.ps1";    Desc = "Does something cool" }
)

# ── Helpers ───────────────────────────────────────────────────────────────────
function Write-Banner {
    Clear-Host
    $width = $Host.UI.RawUI.WindowSize.Width
    $title = " TheRealAshik - Script Launcher "
    $pad   = [math]::Max(0, [math]::Floor(($width - $title.Length) / 2))
    Write-Host ""
    Write-Host (" " * $pad + $title) -ForegroundColor Cyan
    Write-Host (" " * $pad + ("-" * $title.Length)) -ForegroundColor DarkCyan
    Write-Host ""
}

function Write-Menu {
    param([int]$Selected)

    for ($i = 0; $i -lt $Scripts.Count; $i++) {
        $s = $Scripts[$i]
        if ($i -eq $Selected) {
            Write-Host "  >> " -NoNewline -ForegroundColor Yellow
            Write-Host ("{0,-22}" -f $s.Name) -NoNewline -ForegroundColor Black -BackgroundColor Yellow
            Write-Host "  $($s.Desc)" -ForegroundColor DarkYellow
        } else {
            Write-Host "    " -NoNewline
            Write-Host ("{0,-22}" -f $s.Name) -NoNewline -ForegroundColor White
            Write-Host "  $($s.Desc)" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    Write-Host "  [Up/Down] Navigate   [Enter] Run   [Q] Quit" -ForegroundColor DarkGray
    Write-Host ""
}

function Invoke-RemoteScript {
    param([string]$ScriptPath)

    $url = "$RAW_BASE/$ScriptPath"
    Write-Host ""
    Write-Host "  Fetching: $url" -ForegroundColor DarkCyan

    try {
        $code = (New-Object System.Net.WebClient).DownloadString($url)
    } catch {
        Write-Host "  ERROR: Could not fetch script — $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Press any key to return to the menu..." -ForegroundColor DarkGray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    Write-Host "  Running..." -ForegroundColor Green
    Write-Host ""

    # Execute in a child scope so the launcher isn't affected
    Invoke-Expression $code

    Write-Host ""
    Write-Host "  Script finished. Press any key to return to the menu..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# ── Main loop ─────────────────────────────────────────────────────────────────
$selected = 0

while ($true) {
    Write-Banner
    Write-Menu -Selected $selected

    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    switch ($key.VirtualKeyCode) {
        38 { # Up arrow
            $selected = if ($selected -gt 0) { $selected - 1 } else { $Scripts.Count - 1 }
        }
        40 { # Down arrow
            $selected = if ($selected -lt $Scripts.Count - 1) { $selected + 1 } else { 0 }
        }
        13 { # Enter
            Write-Banner
            Invoke-RemoteScript -ScriptPath $Scripts[$selected].Path
        }
        81 { # Q
            Clear-Host
            Write-Host "  Bye!" -ForegroundColor Cyan
            Write-Host ""
            exit 0
        }
        27 { # Escape
            Clear-Host
            Write-Host "  Bye!" -ForegroundColor Cyan
            Write-Host ""
            exit 0
        }
    }
}
