#!/bin/zsh
# P_-Profile für X-Plane 12 – Wiederherstellen unter macOS / restore on macOS
#
# Startet den Installer (StreamDeck/installer_macos.js) im Modus Wiederherstellen: Auswahl „Originalzustand vor den
# P_-Profilen“ (eigene Konfigurationen zurück, P_-Dateien entfernen, auf Wunsch P_-Profile aus der Stream-Deck-Software
# entfernen) oder einer Sicherung (Dateien und auf Wunsch die Stream-Deck-Profile auf deren Stand). Der aktuelle Stand
# wird vorher gesichert.
HIER="${0:A:h}"
osascript -l JavaScript "$HIER/StreamDeck/installer_macos.js" "$HIER" --wiederherstellen
echo
read "?Enter zum Schließen / press Enter to close"
