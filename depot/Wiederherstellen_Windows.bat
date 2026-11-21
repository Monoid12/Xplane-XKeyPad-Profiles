@echo off
rem Startet den PowerShell-Installer der P_-Profile im Modus Wiederherstellen (Originalzustand oder Sicherung).
rem Arbeitsordner ausserhalb des Pakets, Ausfuehrungsrichtlinie nur fuer diesen Aufruf umgangen.
cd /d "%TEMP%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Installieren_Windows.ps1" -Wiederherstellen
