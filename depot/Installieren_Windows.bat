@echo off
rem Startet den PowerShell-Installer der P_-Profile (Ausfuehrungsrichtlinie nur fuer diesen Aufruf umgangen).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Installieren_Windows.ps1"
