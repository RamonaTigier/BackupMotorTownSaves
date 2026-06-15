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
   - MotorTown version detection (SteamDB + manifest)
   - Per-backup version tracking (Characters & Worlds)

 Version:
   1.6.0

 Changelog:
   1.6.0 - Added MotorTown version tracking (LastKnownVersion)
           Added per-backup version storage
           Improved version detection logic
           Fixed status file initialization order
   1.5.0 - Added World-folder integration
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
$Minor = 6
$Patch = 2
$Build = 28
$Tag = "stable"

# Compose version strings
$FullVersion = "$Major.$Minor.$Patch.$Build"
$ReleaseTag  = "v$Major.$Minor.$Patch-$Tag"
$Now = (Get-Date).ToString("dd.MM.yyyy HH:mm:ss")

# Status file
$StatusFile = ".\CharactersBackupStatus.txt"

# Create status file if missing
if (-not (Test-Path $StatusFile)) {
    Set-Content $StatusFile "CharactersBackup="
    Add-Content $StatusFile "CharactersBackupVersion="
    Add-Content $StatusFile "CharactersTest="
    Add-Content $StatusFile "CharactersTestVersion="
    Add-Content $StatusFile "CharactersProd="
    Add-Content $StatusFile "CharactersProdVersion="
    Add-Content $StatusFile "WorldsBackup="
    Add-Content $StatusFile "WorldsBackupVersion="
    Add-Content $StatusFile "WorldsTest="
    Add-Content $StatusFile "WorldsTestVersion="
    Add-Content $StatusFile "WorldsProd="
    Add-Content $StatusFile "WorldsProdVersion="
    Add-Content $StatusFile "LastKnownVersion="
}

# ============================
# Version Detection Functions
# ============================

# Steamapps-Ordner automatisch finden
function Find-SteamAppsPath {
    $possible = @(
        "G:\Steam\steamapps",
        "F:\Steam\steamapps",
        "E:\Steam\steamapps",
        "D:\Steam\steamapps",
        "C:\Program Files (x86)\Steam\steamapps"
    )

    foreach ($path in $possible) {
        if (Test-Path $path) {
            return $path
        }
    }

    return $null
}

# BuildID aus lokalem Manifest lesen
function Get-LocalBuildID {
    $steamApps = Find-SteamAppsPath
    if (-not $steamApps) { return $null }

    $manifest = Join-Path $steamApps "appmanifest_1369670.acf"
    if (-not (Test-Path $manifest)) { return $null }

    $content = Get-Content $manifest
    foreach ($line in $content) {
        if ($line -match '"buildid"\s+"(\d+)"') {
            return $matches[1]
        }
    }

    return $null
}

# Patch Title + BuildID von SteamDB holen
function Get-SteamDBInfo {
    try {
        $url = "https://steamdb.info/app/1369670/patchnotes/"
        $html = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10

        $patchTitle = ($html.Content -split "`n" | Select-String -Pattern "Patch Title").ToString()
        $buildID    = ($html.Content -split "`n" | Select-String -Pattern "BuildID").ToString()

        $patchTitle = ($patchTitle -replace ".*Patch Title:\s*", "").Trim()
        $buildID    = ($buildID -replace ".*BuildID:\s*", "").Trim()

        return [PSCustomObject]@{
            PatchTitle = $patchTitle
            BuildID    = $buildID
        }
    }
    catch {
        return $null
    }
}


# Version bestimmen (automatisch + Fallback)
function Resolve-MotorTownVersion {

    # Statusdatei-Pfad (verwende globale Definition)
    $statusFile = $StatusFile


    # Letzte bekannte Version aus Statusdatei lesen
    $lastKnownVersion = $null
    if (Test-Path $statusFile) {
        $content = Get-Content $statusFile
        foreach ($line in $content) {
            if ($line -match "^LastKnownVersion=(.+)$") {
                $lastKnownVersion = $matches[1].Trim()
            }
        }
    }

    # Automatische Erkennung
    $localBuild = Get-LocalBuildID
    $steamInfo  = Get-SteamDBInfo

    # Wenn BuildID übereinstimmt → Version aus SteamDB übernehmen
    if ($localBuild -and $steamInfo -and $steamInfo.BuildID -eq $localBuild) {
        $version = $steamInfo.PatchTitle

        # LastKnownVersion aktualisieren
        (Get-Content $statusFile) -replace "^LastKnownVersion=.*", "LastKnownVersion=$version" |
            Set-Content $statusFile

        return $version
    }

    # Wenn automatische Erkennung fehlschlägt → letzte bekannte Version verwenden
    if ($lastKnownVersion) {
        Write-Host ""
        Write-Host "Using last known MotorTown version from status file: $lastKnownVersion"
        return $lastKnownVersion
    }

    # Wenn nichts bekannt → Benutzer fragen
    Write-Host ""
    Write-Host "Could not determine MotorTown version automatically."
    Write-Host "Local BuildID: $localBuild"
    if ($steamInfo) { Write-Host "SteamDB BuildID: $($steamInfo.BuildID)" }
    Write-Host ""

    $manual = Read-Host "Please enter MotorTown version manually (e.g. 0.7.18+1)"

    if ($manual) {
        (Get-Content $statusFile) -replace "^LastKnownVersion=.*", "LastKnownVersion=$manual" |
            Set-Content $statusFile
    }

    return $manual

}

$GameVersion = Resolve-MotorTownVersion
$Global:MotorTownVersion = $GameVersion


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

$Worlds       = Join-Path $BasePath "Worlds"
$WorldsBackup = Join-Path $BasePath "Worlds - Backup"
$WorldsTest   = Join-Path $BasePath "Worlds - Test"
$WorldsProd   = Join-Path $BasePath "Worlds - Prod"

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
            $versionKey = "${StatusKey}Version"
            $oldVersion = Get-Status $versionKey

            if ($oldVersion -ne "") {
                Write-Host ("Backup version: {0}" -f $oldVersion)
            }
            else {
                Write-Host "Backup version: unknown"
            }
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
            # Version zusätzlich speichern
            $versionKey = "${StatusKey}Version"
            Set-Status -Key $versionKey -Value $Global:MotorTownVersion
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
function Manage-SaveType {
    param(
        [string]$Type,
        [string]$Source,
        [string]$Backup,
        [string]$Test,
        [string]$Prod
    )

    do {
        Write-Host "--------------------------------------------------------------"
        Write-Host "$Type SaveGame Manager"
        Write-Host "--------------------------------------------------------------"
        Write-Host "1) $Type -> Backup (Version: $GameVersion)"
        Write-Host "2) $Type -> Test   (Version: $GameVersion)"
        Write-Host "3) $Type -> Prod   (Version: $GameVersion)"

        Write-Host "--------------------------------------------------------------"
        $verBackup = Get-Status "${Type}BackupVersion"
        $verTest   = Get-Status "${Type}TestVersion"
        $verProd   = Get-Status "${Type}ProdVersion"

        Write-Host "4) Backup -> $Type (Date: $(Get-Status "${Type}Backup") | Version: $verBackup)"
        Write-Host "5) Test   -> $Type (Date: $(Get-Status "${Type}Test") | Version: $verTest)"
        Write-Host "6) Prod   -> $Type (Date: $(Get-Status "${Type}Prod") | Version: $verProd)"

        Write-Host "--------------------------------------------------------------"
        Write-Host "8) $Type -> ALL (Backup, Test, Prod)"

        Write-Host "--------------------------------------------------------------"
        Write-Host "0) Back"

        Write-Host "--------------------------------------------------------------"

        $choice = Read-Host "Select"

        switch ($choice) {
            "1" { Copy-FolderContent -Source $Source -Target $Backup -StatusKey "${Type}Backup" }
            "2" { Copy-FolderContent -Source $Source -Target $Test   -StatusKey "${Type}Test" }
            "3" { Copy-FolderContent -Source $Source -Target $Prod   -StatusKey "${Type}Prod" }

            "4" { Copy-FolderContent -Source $Backup -Target $Source -StatusKey "${Type}Backup" }
            "5" { Copy-FolderContent -Source $Test   -Target $Source -StatusKey "${Type}Test" }
            "6" { Copy-FolderContent -Source $Prod   -Target $Source -StatusKey "${Type}Prod" }

            "8" {
                Copy-FolderContent -Source $Source -Target $Backup -StatusKey "${Type}Backup"
                Copy-FolderContent -Source $Source -Target $Test   -StatusKey "${Type}Test"
                Copy-FolderContent -Source $Source -Target $Prod   -StatusKey "${Type}Prod"
            }

            "0" { return }
            default { Write-Host "Invalid input." }
        }

    } while ($true)
}

# Main loop
do {
    Write-Host "==============================="
    Write-Host " Select SaveGame Type"
    Write-Host "==============================="
    Write-Host "1) Characters"
    Write-Host "2) Worlds"
    Write-Host "0) Exit"
    Write-Host "==============================="

    $mainChoice = Read-Host "Select"

    switch ($mainChoice) {

        "1" {
            Manage-SaveType -Type "Characters" `
                -Source $Characters `
                -Backup $Backup `
                -Test $Test `
                -Prod $Prod
        }

        "2" {
            Manage-SaveType -Type "Worlds" `
                -Source $Worlds `
                -Backup $WorldsBackup `
                -Test $WorldsTest `
                -Prod $WorldsProd
        }

        "0" { Write-Host "Exit." }
        default { Write-Host "Invalid input." }
    }

} while ($mainChoice -ne "0")
