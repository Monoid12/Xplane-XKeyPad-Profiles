#!/bin/zsh
# P_-Profile für X-Plane 12 – Installation unter macOS / installation on macOS
#
# Startet den eigentlichen Installer StreamDeck/installer_macos.js (JavaScript for Automation): Auswahl der Profile,
# der FlyWithLua-Skripte und der AeroACARS-Kacheln, Kopieren der Dateien mit Sicherung, Kreis Vor/Zurück über alle
# installierten P_-Profile. Ein erneuter Aufruf installiert weitere Profile nach.
HIER="${0:A:h}"
osascript -l JavaScript "$HIER/StreamDeck/installer_macos.js" "$HIER"
echo
read "?Enter zum Schließen / press Enter to close"
