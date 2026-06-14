# BackupMotorTownSaves
GERMAN version below.

# MotorTown SaveGame Manager 🚗💾

![Status](https://img.shields.io/badge/Status-Active-brightgreen)
![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue)
![License](https://img.shields.io/badge/License-MIT-yellow)
![Version](https://img.shields.io/badge/Version-1.4.0-orange)

A powerful, color‑coded PowerShell tool for managing MotorTown savegames.  
It creates backups, restores savegame states, sorts them by date, warns about
outdated backups, and supports multi‑target backup operations.

---

## ✨ Features

- 🔄 **Backup** the `Characters` folder to:
  - `Backup`
  - `Test`
  - `Prod`
- ♻️ **Restore** from any of the three target folders
- 🧹 **Automatic cleanup** of the target folder before copying
- 🔢 **File counting** (source & target)
- 🕒 **Timestamps** in `yyyyMMdd HH:mm:ss` format
- 📅 **Sorted backup list** (newest first)
- 🎨 **Color‑coded backup age:**
  - **Green** < 7 days  
  - **Yellow** 7–29 days  
  - **Red** ≥ 30 days  
  - **Gray** = no backup available
- 📦 **Multi‑backup** (Characters → Backup, Test, Prod)
- 📝 **Status file** for tracking all backup timestamps

---

## 📂 Folder Structure

%LOCALAPPDATA%\MotorTown\Saved\SaveGames\

├── Characters

├── Characters - Backup

├── Characters - Test

└── Characters - Prod


All paths are generated dynamically using `$env:LOCALAPPDATA`.

---

## 🚀 Usage

Run the script in PowerShell:

```powershell
.\MotorTownSaveManager.ps1
```


MotorTown SaveGame Manager 🚗💾

Ein leistungsstarkes, farbcodiertes PowerShell‑Tool zur Verwaltung von MotorTown‑Savegames.
Erstellt Backups, stellt Spielstände wieder her, sortiert nach Datum, warnt vor alten Backups
und unterstützt Multi‑Backup‑Operationen.

✨ Features
🔄 Backup des Characters‑Ordners nach:
Backup
Test
Prod

♻️ Restore aus allen drei Zielordnern
🧹 Automatisches Leeren des Zielordners vor dem Kopieren
🔢 Dateizählung (Source & Target)
🕒 Zeitstempel im Format yyyyMMdd HH:mm:ss
📅 Sortierung nach Datum (neueste zuerst)
🎨 Farbcodierung nach Alter:

Grün < 7 Tage
Gelb 7–29 Tage
Rot ≥ 30 Tage
Grau = kein Backup vorhanden

📦 Multi‑Backup (Characters → Backup, Test, Prod)
📝 Statusdatei zur Nachverfolgung aller Backups

📂 Ordnerstruktur

%LOCALAPPDATA%\MotorTown\Saved\SaveGames\

 ├── Characters
 
 ├── Characters - Backup
 
 ├── Characters - Test
 
 └── Characters - Prod
Alle Pfade werden dynamisch über $env:LOCALAPPDATA erzeugt.

🚀 Verwendung
Starte das Skript einfach in PowerShell:

powershell
.\MotorTownSaveManager.ps1

---

Wenn du möchtest, kann ich dir zusätzlich:

- eine **LICENSE** Datei generieren  
- ein **CHANGELOG.md** erstellen  
- ein **GitHub Release Template** bauen  
- oder ein **Projekt‑Logo** designen  

Sag einfach Bescheid.
