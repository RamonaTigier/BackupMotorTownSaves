# ============================
# MotorTown SaveGame Manager
# ============================

<#
===============================================================
 MotorTown SaveGame Manager
===============================================================
 Description:
   Script for managing MotorTown savegame backups.
   Supports backup and restore between Characters,
   Backup, Test and Prod folders, including multi-target
   backup and timestamp tracking.

 Features:
   - Backup Characters to Backup, Test, Prod
   - Restore Characters from Backup, Test, Prod
   - Sorted restore list (newest first)
   - Color-coded backup age (green/yellow/red)
   - Human readable timestamps (dd.MM.yyyy HH:mm:ss)
   - Multi-backup option (Characters -> ALL)
   - Status file for tracking backup timestamps
   - Target folder cleanup before copying
   - File count display for source and target

 Version:
   1.4.0

 Changelog:
   1.4.0 - Added color-coded backup age (green/yellow/red)
           Added correct date sorting (newest first)
           Added file count display in copy dialog
           Added target folder cleanup before copy
   1.3.0 - Added multi-backup option (menu item 8)
           Added second-level timestamps
           Improved human-readable date formatting
   1.2.0 - Added date display in menu
           Added restore date visibility
   1.1.0 - Added status file with timestamps
   1.0.0 - Initial version with basic backup/restore

 Author:
   Franklyn

 Created:
   14.06.2026

 Notes:
   - Timestamps stored as: yyyyMMdd HH:mm:ss
   - Status file: CharactersBackupStatus.txt
   - Script is ASCII-safe to avoid encoding issues
===============================================================
#>

# Manual version definition
$Major = 1
$Minor = 4
$Patch = 0
$Build = 14
$Tag = "stable"

# Compose version strings
$FullVersion = "$Major.$Minor.$Patch.$Build"
$ReleaseTag  = "v$Major.$Minor.$Patch-$Tag"
$Now = (Get-Date).ToString("dd.MM.yyyy HH:mm:ss")

# Compact dynamic header
# UTF-8 aktivieren
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Windows Codepage auf UTF-8 setzen
chcp 65001 > $null
$Header = @"
▓█████▄  ▄▄▄      ▄████▄   ██ ▄█▀ █    ██  ██▓███
▒██▀ ██▌▒████▄   ▒██▀ ▀█   ██▄█▒  ██  ▓██▒▓██░  ██▒
░██   █▌▒██  ▀█▄ ▒▓█    ▄ ▓███▄░ ▓██  ▒██░▓██░ ██▓▒
░▓█▄   ▌░██▄▄▄▄██▒▓▓▄ ▄██▒▓██ █▄ ▓▓█  ░██░▒██▄█▓▒ ▒
░▒████▓  ▓█   ▓██▒ ▓███▀ ░▒██▒ █▄▒▒█████▓ ▒██▒ ░  ░
 ▒▒▓  ▒  ▒▒   ▓▒█░ ░▒ ▒  ░▒ ▒▒ ▓▒░▒▓▒ ▒ ▒ ▒▓▒░ ░  ░
 ░ ▒  ▒   ▒   ▒▒ ░ ░  ▒   ░ ░▒ ▒░░░▒░ ░ ░ ░▒ ░
 ░ ░  ░   ░   ▒  ░        ░ ░░ ░  ░░░ ░ ░ ░░
   ░          ░  ░░ ░      ░  ░      ░
 ░                  ░

        B a c k u p M o t o r T o w n S a v e s
Version: $ReleaseTag
"@

Write-Host $Header

# Paths
$BasePath = Join-Path $env:LOCALAPPDATA "MotorTown\Saved\SaveGames"

$Characters = Join-Path $BasePath "Characters"
$Backup     = Join-Path $BasePath "Characters - Backup"
$Test       = Join-Path $BasePath "Characters - Test"
$Prod       = Join-Path $BasePath "Characters - Prod"

# Status file
$StatusFile = ".\CharactersBackupStatus.txt"

# Create status file if missing
if (-not (Test-Path $StatusFile)) {
    Set-Content $StatusFile "Backup="
    Add-Content $StatusFile "Test="
    Add-Content $StatusFile "Prod="
}

# Read status
function Get-Status {
    param([string]$Key)

    $line = Select-String -Path $StatusFile -Pattern "^$Key="
    if ($line) {
        return $line.Line.Split("=")[1]
    }
    return ""
}

# Write status
function Set-Status {
    param(
        [string]$Key,
        [string]$Value
    )

    $content = Get-Content $StatusFile
    $new = @()

    foreach ($line in $content) {
        if ($line -like "$Key=*") {
            $new += "$Key=$Value"
        }
        else {
            $new += $line
        }
    }

    $new | Set-Content $StatusFile
}

# Copy function
function Copy-FolderContent {
    param(
        [string]$Source,
        [string]$Target,
        [string]$StatusKey
    )

    # Check source folder
    if (-not (Test-Path $Source)) {
        Write-Host "ERROR: Source folder does not exist:"
        Write-Host "       $Source"
        return
    }

    # Count source files
    $sourceFiles = Get-ChildItem -Path $Source -File -ErrorAction SilentlyContinue
    $sourceCount = $sourceFiles.Count

    if ($sourceCount -eq 0) {
        Write-Host "ERROR: Source folder is empty:"
        Write-Host "       $Source"
        return
    }

    # Ensure target folder exists
    try {
        if (-not (Test-Path $Target)) {
            New-Item -ItemType Directory -Path $Target -ErrorAction Stop | Out-Null
        }
    }
    catch {
        Write-Host "ERROR: Could not create target folder:"
        Write-Host "       $Target"
        Write-Host "Reason: $($_.Exception.Message)"
        return
    }

    # Count target files BEFORE clearing
    $targetFiles = Get-ChildItem -Path $Target -File -ErrorAction SilentlyContinue
    $targetCount = $targetFiles.Count

    # Show last backup date
    if ($StatusKey -ne "") {
        $oldDate = Get-Status -Key $StatusKey
        if ($oldDate -ne "") {
            Write-Host ("Last backup for {0}: {1}" -f $StatusKey, $oldDate)
        }
        else {
            Write-Host ("No previous backup for {0}." -f $StatusKey)
        }
    }

    # Warn if backup is older than 7 days
    if ($StatusKey -ne "" -and $oldDate -ne "") {

        try {
            $parsed = [datetime]::ParseExact($oldDate, "yyyyMMdd HH:mm:ss", $null)
            $age = (New-TimeSpan -Start $parsed -End (Get-Date)).Days

            if ($age -ge 7) {
                Write-Host ""
                Write-Host "WARNING: This backup is older than $age days."
                Write-Host "         Possible version conflicts may occur."
                Write-Host "         The script does not detect or resolve"
                Write-Host "         savegame version mismatches."
                Write-Host ""
            }
        }
        catch {
            Write-Host "WARNING: Could not parse backup timestamp."
        }
    }

    Write-Host ""
    Write-Host "Copy from:"
    Write-Host "  $Source"
    Write-Host "  Files: $sourceCount"
    Write-Host ""
    Write-Host "To:"
    Write-Host "  $Target"
    Write-Host "  Files before clearing: $targetCount"
    Write-Host ""

    $confirm = Read-Host "Execute, clear target and overwrite? (Yes/No)"

    if ($confirm -match "^(Yes|yes|Y|y)$") {

        # Clear target folder first
        try {
            Get-ChildItem -Path $Target -Recurse -Force -ErrorAction Stop | Remove-Item -Recurse -Force -ErrorAction Stop
        }
        catch {
            Write-Host "ERROR: Could not clear target folder:"
            Write-Host "       $Target"
            Write-Host "Reason: $($_.Exception.Message)"
            return
        }

        # Copy files
        try {
            Copy-Item -Path "$Source\*" -Destination $Target -Recurse -Force -ErrorAction Stop
        }
        catch {
            Write-Host "ERROR: Copy operation failed."
            Write-Host "Reason: $($_.Exception.Message)"
            return
        }

        # Update timestamp
        if ($StatusKey -ne "") {
            $now = (Get-Date).ToString("yyyyMMdd HH:mm:ss")
            Set-Status -Key $StatusKey -Value $now
        }

        # Count target files AFTER copy
        $newTargetCount = (Get-ChildItem -Path $Target -File -ErrorAction SilentlyContinue).Count

        Write-Host ""
        Write-Host "Done."
        Write-Host "Files now in target: $newTargetCount"
        Write-Host ""
    }
    else {
        Write-Host ""
        Write-Host "Canceled."
        Write-Host ""
    }
}

# Menu
function Show-Menu {

    function Format-DateHuman {
        param([string]$raw)

        if ($raw -eq "" -or $raw -eq $null) { return "none" }

        # raw format: yyyyMMdd HH:mm:ss
        $parts = $raw.Split(" ")
        $date = $parts[0]
        $time = $parts[1]

        $year  = $date.Substring(0,4)
        $month = $date.Substring(4,2)
        $day   = $date.Substring(6,2)

        return "$day.$month.$year $time"
    }

    # Build proper objects with parsed DateTime
    $dates = @()

    foreach ($key in @("Backup","Test","Prod")) {
        $raw = Get-Status -Key $key

        if ($raw -and $raw -ne "") {
            try {
                $parsed = [datetime]::ParseExact($raw, "yyyyMMdd HH:mm:ss", $null)
            }
            catch {
                $parsed = Get-Date "1900-01-01"
            }
        }
        else {
            $parsed = Get-Date "1900-01-01"
            $raw = ""
        }

        $dates += [pscustomobject]@{
            Key    = $key
            Raw    = $raw
            Parsed = $parsed
        }
    }

    # Sort newest first
    $sorted = $dates | Sort-Object Parsed -Descending

    Write-Host "--------------------------------------------------------------"
    Write-Host "1) Characters -> Backup"
    Write-Host "2) Characters -> Test"
    Write-Host "3) Characters -> Prod"
    Write-Host "--------------------------------------------------------------"

    foreach ($entry in $sorted) {

        $human = Format-DateHuman $entry.Raw

        # Default color
        $color = "DarkGray"

        if ($entry.Raw -ne "") {
            try {
                $age = (New-TimeSpan -Start $entry.Parsed -End (Get-Date)).Days

                if ($age -lt 7) {
                    $color = "Green"
                }
                elseif ($age -lt 30) {
                    $color = "Yellow"
                }
                else {
                    $color = "Red"
                }
            }
            catch {
                $color = "DarkGray"
            }
        }

        switch ($entry.Key) {
            "Backup" { Write-Host ("4) Backup -> Characters   (Last: {0})" -f $human) -ForegroundColor $color }
            "Test"   { Write-Host ("5) Test -> Characters     (Last: {0})" -f $human) -ForegroundColor $color }
            "Prod"   { Write-Host ("6) Prod -> Characters     (Last: {0})" -f $human) -ForegroundColor $color }
        }
    }

    Write-Host "--------------------------------------------------------------"
    Write-Host "8) Characters -> ALL (Backup, Test, Prod)"
    Write-Host "--------------------------------------------------------------"
    Write-Host "0) Exit"
    Write-Host "--------------------------------------------------------------"
}

# Main loop
do {
    Show-Menu
    $choice = Read-Host "Select"

    switch ($choice) {
        "1" { Copy-FolderContent -Source $Characters -Target $Backup -StatusKey "Backup" }
        "2" { Copy-FolderContent -Source $Characters -Target $Test   -StatusKey "Test" }
        "3" { Copy-FolderContent -Source $Characters -Target $Prod   -StatusKey "Prod" }

        # Sorted restore actions
        "4" { Copy-FolderContent -Source $Backup   -Target $Characters -StatusKey "Backup" }
        "5" { Copy-FolderContent -Source $Test     -Target $Characters -StatusKey "Test" }
        "6" { Copy-FolderContent -Source $Prod     -Target $Characters -StatusKey "Prod" }

        # Copy to all three
        "8" {
            Copy-FolderContent -Source $Characters -Target $Backup -StatusKey "Backup"
            Copy-FolderContent -Source $Characters -Target $Test   -StatusKey "Test"
            Copy-FolderContent -Source $Characters -Target $Prod   -StatusKey "Prod"
        }

        "0" { Write-Host "Exit." }
        default { Write-Host "Invalid input." }
    }

} while ($choice -ne "0")
