#Requires -Version 5.1

# Force Delete Script
# Requests admin elevation, then forcefully deletes a specified file or folder.

# --- Self-elevate to Administrator if not already ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting administrator privileges..." -ForegroundColor Yellow
    $scriptPath = $MyInvocation.MyCommand.Definition
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
    exit
}

# --- Main Script (runs as Admin) ---
Write-Host ""
Write-Host "=== Force Delete Tool ===" -ForegroundColor Cyan
Write-Host "Running as Administrator." -ForegroundColor Green
Write-Host ""

# Get path from user
$targetPath = Read-Host "Enter the full path of the file or folder to delete"

# Trim quotes in case the user dragged and dropped a path
$targetPath = $targetPath.Trim('"').Trim("'")

# Validate input
if ([string]::IsNullOrWhiteSpace($targetPath)) {
    Write-Host "No path provided. Exiting." -ForegroundColor Red
    pause
    exit 1
}

if (-not (Test-Path -LiteralPath $targetPath)) {
    Write-Host "Path not found: $targetPath" -ForegroundColor Red
    pause
    exit 1
}

# Show what will be deleted
$item = Get-Item -LiteralPath $targetPath
$itemType = if ($item.PSIsContainer) { "folder" } else { "file" }
Write-Host ""
Write-Host "Target $itemType : $targetPath" -ForegroundColor Yellow

# Confirm before deleting
$confirm = Read-Host "Are you sure you want to PERMANENTLY delete this $itemType? (yes/no)"
if ($confirm -notin @("yes", "y")) {
    Write-Host "Deletion cancelled." -ForegroundColor Cyan
    pause
    exit 0
}

# --- Kill locking processes and services ---

# Collect all .exe files inside the target (or the target itself if it's a file)
$exeFiles = @()
if ($item.PSIsContainer) {
    $exeFiles = Get-ChildItem -LiteralPath $targetPath -Recurse -Filter "*.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
} else {
    if ($targetPath -like "*.exe") { $exeFiles = @($targetPath) }
}

foreach ($exe in $exeFiles) {
    $exeName = [System.IO.Path]::GetFileNameWithoutExtension($exe)

    # Stop matching services
    $services = Get-Service | Where-Object { $_.DisplayName -like "*$exeName*" -or $_.Name -like "*$exeName*" }
    foreach ($svc in $services) {
        Write-Host "Stopping service: $($svc.Name)" -ForegroundColor Gray
        try {
            Stop-Service -Name $svc.Name -Force -ErrorAction Stop
            # Disable so it doesn't restart
            Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction SilentlyContinue
        } catch {
            # Use sc.exe as fallback
            & sc.exe stop $svc.Name 2>&1 | Out-Null
            & sc.exe config $svc.Name start= disabled 2>&1 | Out-Null
        }
    }

    # Also stop by binary path match
    $servicesByPath = Get-WmiObject Win32_Service | Where-Object { $_.PathName -like "*$exeName*" }
    foreach ($svc in $servicesByPath) {
        Write-Host "Stopping service (by path): $($svc.Name)" -ForegroundColor Gray
        & sc.exe stop $svc.Name 2>&1 | Out-Null
        & sc.exe config $svc.Name start= disabled 2>&1 | Out-Null
    }

    # Kill matching processes
    $processes = Get-Process | Where-Object { $_.Name -like "*$exeName*" }
    foreach ($proc in $processes) {
        Write-Host "Killing process: $($proc.Name) (PID $($proc.Id))" -ForegroundColor Gray
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
        } catch {
            & taskkill /PID $proc.Id /F 2>&1 | Out-Null
        }
    }
}

# Brief pause to let OS release file handles
Start-Sleep -Milliseconds 800

# --- Take ownership and grant permissions ---
Write-Host "Taking ownership..." -ForegroundColor Gray
& takeown /F "$targetPath" /R /D Y 2>&1 | Out-Null

Write-Host "Granting full permissions..." -ForegroundColor Gray
& icacls "$targetPath" /grant "$($env:USERNAME):F" /T /C /Q 2>&1 | Out-Null

# --- Delete ---
Write-Host "Deleting..." -ForegroundColor Gray

# First attempt: PowerShell
$success = $false
try {
    Remove-Item -LiteralPath $targetPath -Recurse -Force -ErrorAction Stop
    $success = $true
} catch {
    Write-Host "Standard delete failed, trying robocopy method..." -ForegroundColor Gray
}

# Second attempt: robocopy empty-folder trick (effective for stubborn folders)
if (-not $success -and $item.PSIsContainer) {
    try {
        $emptyDir = Join-Path $env:TEMP "empty_robocopy_src_$(Get-Random)"
        New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
        & robocopy "$emptyDir" "$targetPath" /MIR /NFL /NDL /NJH /NJS /NC /NS 2>&1 | Out-Null
        Remove-Item -LiteralPath $emptyDir -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $targetPath -Recurse -Force -ErrorAction Stop
        $success = $true
    } catch {
        Write-Host "Robocopy method failed, scheduling delete on next reboot..." -ForegroundColor Gray
    }
}

# Third attempt: schedule deletion on reboot using MoveFileEx
if (-not $success) {
    $code = @"
using System;
using System.Runtime.InteropServices;
public class MoveFileEx {
    [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    public static extern bool MoveFileExW(string lpExistingFileName, string lpNewFileName, int dwFlags);
}
"@
    Add-Type -TypeDefinition $code -Language CSharp -ErrorAction SilentlyContinue

    $items = @($targetPath)
    if ($item.PSIsContainer) {
        $items = Get-ChildItem -LiteralPath $targetPath -Recurse -Force | Sort-Object FullName -Descending | Select-Object -ExpandProperty FullName
        $items += $targetPath
    }

    foreach ($i in $items) {
        [MoveFileEx]::MoveFileExW($i, $null, 4) | Out-Null  # MOVEFILE_DELAY_UNTIL_REBOOT
    }

    Write-Host ""
    Write-Host "Could not delete while Windows is running." -ForegroundColor Yellow
    Write-Host "Scheduled for deletion on next reboot: $targetPath" -ForegroundColor Yellow
    $reboot = Read-Host "Reboot now? (yes/no)"
    if ($reboot -in @("yes", "y")) {
        Restart-Computer -Force
    }
    pause
    exit 0
}

Write-Host ""
Write-Host "Successfully deleted: $targetPath" -ForegroundColor Green

Write-Host ""
pause
