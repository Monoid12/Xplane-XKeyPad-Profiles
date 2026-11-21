@echo off
rem Startet den PowerShell-Installer der P_-Profile (Ausfuehrungsrichtlinie nur fuer diesen Aufruf umgangen).
rem Arbeitsordner ausserhalb des Pakets: der Installer verschiebt den Ordner P_Profile zum Schluss nach Resources\plugins
cd /d "%TEMP%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Installieren_Windows.ps1"
