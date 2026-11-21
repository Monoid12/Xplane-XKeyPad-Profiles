#!/bin/zsh
# P_-Profile für X-Plane 12 – Update-Helfer (macOS)
#
# Vom Installer als LaunchAgent com.p-profile.update eingerichtet (~/Library/LaunchAgents/com.p-profile.update.plist)
# und nach ~/Library/Application Support/P_Profile/update_helfer.sh kopiert. launchd startet ihn, wenn sich der Ordner
# P_Profile ändert (SkunkCrafts Updater), alle 30 Minuten und bei der Anmeldung. Der Ordner liegt in
# <X-Plane>/Resources/plugins/P_Profile, bei älteren Installationen noch direkt in <X-Plane>/P_Profile.
#
# Er startet den Installer im Update-Modus (Fenster mit den Profilen), wenn
#   - im Ordner P_Profile eine NEUERE Version liegt als die zuletzt installierte (installiert.txt),
#   - der Updater fertig ist (Version in skunkcrafts_updater.cfg = VERSION, seit einer Minute keine Änderung),
#   - „Später“ für diese Version nicht vor weniger als 12 Stunden gewählt wurde (abgelehnt.txt),
#   - nicht schon ein Lauf aktiv ist (Sperre lauf.lock mit Prozessnummer).
# Wartet X-Plane noch, übernimmt das der Installer. Protokoll: helfer.log im selben Ordner.
#
# Aufruf: update_helfer.sh <X-Plane-Ordner>
# Abschalten: Installer erneut starten und „Automatische Updates“ mit Nein beantworten.
# Testmodus (nur Entwicklung): P_TEST_ZUSTAND (Zustandsordner), P_TEST_WARTEN (Sekunden zwischen den Prüfungen);
# die übrigen P_TEST_*-Variablen reicht er an den Installer weiter.

emulate -L zsh
autoload -Uz is-at-least

XP="$1"
PP="$XP/Resources/plugins/P_Profile"
[[ -d "$PP" ]] || PP="$XP/P_Profile"
ZUSTAND="${P_TEST_ZUSTAND:-$HOME/Library/Application Support/P_Profile}"   # P_TEST_*: nur Entwicklung
WARTEN=${P_TEST_WARTEN:-30}
zeit() { date '+%Y-%m-%d %H:%M:%S' }

[[ -n "$XP" && -f "$PP/VERSION" && -f "$PP/StreamDeck/installer_macos.js" ]] || exit 0

neu=$(<"$PP/VERSION"); neu=${neu//[$'\r\n\t ']/}
alt=$(cat "$ZUSTAND/installiert.txt" 2>/dev/null); alt=${alt//[$'\r\n\t ']/}
[[ -n "$neu" && "$neu" != "$alt" ]] || exit 0
# nur aufwärts: liegt die installierte Version gleich hoch oder höher (z. B. per ZIP neuer installiert), nichts tun
if [[ -n "$alt" ]] && is-at-least "$neu" "$alt"; then exit 0; fi

# „Später“ für diese Version: frühestens nach 12 Stunden erneut fragen
if [[ -f "$ZUSTAND/abgelehnt.txt" ]]; then
  read -r av at < "$ZUSTAND/abgelehnt.txt"
  if [[ "$av" == "$neu" && "$at" == <-> ]] && (( $(date +%s) - at < 43200 )); then exit 0; fi
fi

# Updater fertig? Version in der cfg = VERSION und seit einer Minute keine Datei im Ordner geändert (max. 10 Minuten warten)
for i in {1..20}; do
  cfg=$(grep '^version|' "$PP/skunkcrafts_updater.cfg" 2>/dev/null | cut -d'|' -f2 | tr -d '\r ')
  if [[ "$cfg" == "$neu" && -z $(find "$PP" -mmin -1 -print -quit 2>/dev/null) ]]; then break; fi
  if (( i == 20 )); then echo "$(zeit) Update $alt → $neu: Updater noch nicht fertig – nächster Versuch später"; exit 0; fi
  sleep $WARTEN
done

# Sperre: nur ein Lauf zur Zeit; eine verwaiste Sperre (Prozess beendet) wird übernommen
mkdir -p "$ZUSTAND"
SPERRE="$ZUSTAND/lauf.lock"
if ! mkdir "$SPERRE" 2>/dev/null; then
  pid=$(cat "$SPERRE/pid" 2>/dev/null)
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then exit 0; fi
  rm -rf "$SPERRE"; mkdir "$SPERRE" || exit 0
fi
print $$ > "$SPERRE/pid"
trap 'rm -rf "$SPERRE"' EXIT

echo "$(zeit) Update ${alt:-–} → $neu: Installer startet"
osascript -l JavaScript "$PP/StreamDeck/installer_macos.js" "$PP" --aktualisieren
echo "$(zeit) Installer beendet (Status $?)"
