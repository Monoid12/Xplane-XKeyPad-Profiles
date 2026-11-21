# P_-Profile für X-Plane 12 – Installation unter Windows (PowerShell 5.1 oder neuer)
#
# Gleicher Ablauf wie der macOS-Installer (StreamDeck/installer_macos.js):
#   0. Sprache Deutsch/English wählen (vorbelegt: bisherige Wahl, sonst Systemsprache; Update-Modus: bisherige Wahl ohne
#      Frage). Sie gilt für die Texte des Installers und die Tastentexte: Deutsch ZURÜCK/VOR/STUMM/TAUB, Englisch
#      PREV/NEXT/MUTE/DEAF und BACK auf den Unterseiten (Bilder aus StreamDeck\Sprache).
#   1. Prüfen: X-Plane beendet (im Update-Modus: warten, bis X-Plane beendet ist), X-Plane-Ordner (P_Profile liegt in
#      <X-Plane>\Resources\plugins oder – ältere Versionen – direkt in <X-Plane>; sonst C:\X-Plane 12, sonst Auswahl).
#   2.–5. Ein Fenster mit allen Wahlmöglichkeiten:
#   2. Profile (Häkchen mit Status). Vorbelegt: bereits installierte P_-Profile und Profile, deren Flugzeug im
#      Aircraft-Ordner gefunden wird (Update-Modus: nur die installierten). Ein erneuter Aufruf installiert weitere nach.
#   3. FlyWithLua-Skripte (optional, vorbelegt: die für die gewählten Flugzeuge nötigen; Update-Modus: zusätzlich die
#      bereits installierten; neu angehakte Profile haken ihre nötigen Skripte mit an).
#   4. AeroACARS-Kacheln (Startseite XL, Reihe 4, 7 Tasten) anzeigen oder ausblenden (vorbelegt: bisherige Wahl); ebenso
#      die Discord-Tasten STUMM/TAUB (vorbelegt: bisherige Wahl, sonst Discord-Plugin der Stream-Deck-Software vorhanden).
#   5. Automatische Updates: Update-Helfer (geplante Aufgabe „P_Profile Update“) einrichten oder entfernen.
#   Plugins: Better Pushback, SimLoad, X-Camera, AviTab, xPilot je ein Häkchen (vorbelegt: Ordner in Resources\plugins
#      vorhanden; Update-Modus: bisherige Wahl). Ein abgewähltes Plugin gilt für die gewählten Profile: Kommandos des
#      Plugins in der X-KeyPad-Konfiguration → sim/none/none, Datarefs → leer (reiner Textersatz, sonst verwirft X-KeyPad
#      die ganze Konfiguration); Stream-Deck-Tasten auf diese X-KeyPad-Tasten entfallen, ebenso Ordner, deren Seite danach
#      nur noch die Zurück-Taste hat (der Platz bleibt leer); ohne X-Camera keine Sichten-Datei.
#      Paketdateien X-Plane\plugins.txt und plugin_tasten.txt (siehe plugins_optional.py); gemerkte Wahl in
#      %LOCALAPPDATA%\P_Profile\plugins.txt (Zeilen „Kürzel=1|0“).
#   6. Flugzeugdateien (X-KeyPad-Konfiguration, X-Camera-Sichten) neben die passende .acf-Datei kopieren.
#   7. Stream-Deck-Profile nach %APPDATA%\Elgato\StreamDeck\ProfilesV3 (Geräte-Platzhalter → eigene Geräte, Tasten
#      abgewählter Plugins entfernen), danach
#      Vor/Zurück aller installierten P_-Profile im Kreis neu verknüpfen und die AeroACARS-Wahl auf alle anwenden.
#   8. Installierte Version merken (%LOCALAPPDATA%\P_Profile\installiert.txt), ebenso Sprache (sprache.txt).
#   9. Liegt der Ordner P_Profile noch direkt in <X-Plane>, wird er zum Schluss nach <X-Plane>\Resources\plugins\P_Profile
#      verschoben (ein dort schon vorhandener Ordner wandert in die Sicherung).
# Update-Modus (Schalter -Aktualisieren): vom Update-Helfer (update_helfer.ps1) gestartet, sobald der SkunkCrafts
# Updater im Ordner X-Plane 12\P_Profile eine neuere Version abgelegt hat. „Später“ merkt Version und Zeitpunkt in
# abgelehnt.txt; der Helfer fragt nach 12 Stunden erneut.
# Vorhandene Dateien werden vorher nach Dokumente\P_Profile_Sicherung_<Zeitstempel>\ gesichert, im Update-Modus nach
# %LOCALAPPDATA%\P_Profile\Sicherungen\<Zeitstempel>\ (die letzten drei bleiben); inhalt.txt nennt je Eintrag den Originalpfad.
# Originale: Ersetzt der Installer eine Flugzeugdatei, die nicht von den P_-Profilen stammt (z. B. eine eigene
# X-KeyPad-Konfiguration), kommt sie einmalig und dauerhaft nach %LOCALAPPDATA%\P_Profile\Original\<Laufwerk>\<Pfad>;
# dateien.txt merkt je Datei „ersetzt“, „neu“ (gab es vorher nicht) oder „p“ (war schon eine P_-Datei).
# Wiederherstellen (Schalter -Wiederherstellen, gestartet von Wiederherstellen_Windows.bat): „Originalzustand vor den
# P_-Profilen“ oder eine Sicherung wählen; der aktuelle Stand wird vorher gesichert.
# Start über Installieren_Windows.bat (umgeht die Ausführungsrichtlinie nur für dieses Skript).
param([switch]$Aktualisieren, [switch]$Wiederherstellen)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$Hier = Split-Path -Parent $MyInvocation.MyCommand.Path
$Stempel = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$Zustand = Join-Path $env:LOCALAPPDATA 'P_Profile'
$Sicherung = $(if ($Aktualisieren) { Join-Path $Zustand "Sicherungen\$Stempel" } else { Join-Path ([Environment]::GetFolderPath('MyDocuments')) "P_Profile_Sicherung_$Stempel" })
$SdProfile = Join-Path $env:APPDATA 'Elgato\StreamDeck\ProfilesV3'
$PlatzXL = '@(1)[4057/143/P0PROFILXL000]'
$PlatzPlus = '@(1)[4057/132/P0PROFILPLUS0]'
$ModellXL = '20GAT9902'
$ModellPlus = '20GBD9901'
$AeroAcars = 'eu.german-sky-group.aeroacars'
$Discord = 'com.elgato.discord'
# Tastenbilder je Sprache (StreamDeck\Sprache\de|en): Rolle → Datei. ZURÜCK ist deutsch für Kreis und Unterseite gleich.
$SprachBild = @{
    de = @{ prev = 'zurueck.png'; back = 'zurueck.png'; next = 'vor.png'; mute = 'd_mute.png'; mute_an = 'd_mute_an.png'; deaf = 'd_deaf.png'; deaf_an = 'd_deaf_an.png' }
    en = @{ prev = 'en_prev.png'; back = 'en_back.png'; next = 'en_next.png'; mute = 'en_mute.png'; mute_an = 'en_mute_an.png'; deaf = 'en_deaf.png'; deaf_an = 'en_deaf_an.png' }
}
$Aufgabe = 'P_Profile Update'
$LeerKommando = 'sim/none/none'                 # X-Plane-Kommando „Do nothing“
$Zurueck = 'com.elgato.streamdeck.profile.backtoparent'
$OrdnerAktion = 'com.elgato.streamdeck.profile.openchild'
$Utf8 = New-Object System.Text.UTF8Encoding $false
$script:DE = (Get-Culture).TwoLetterISOLanguageName -eq 'de'
function T($de, $en) { if ($script:DE) { $de } else { $en } }
$Version = (Get-Content (Join-Path $Hier 'VERSION') -ErrorAction SilentlyContinue | Select-Object -First 1)
if ($Version) { $Version = $Version.Trim() }

function Abbruch($text) {
    [System.Windows.Forms.MessageBox]::Show($text, (T 'P_-Profile – Installation' 'P_ Profiles – Installation')) | Out-Null
    exit 1
}

# Update-Modus: „Später“ merken (Version, Zeitpunkt) – der Helfer fragt nach 12 Stunden erneut
function Spaeter {
    New-Item -ItemType Directory -Force -Path $Zustand | Out-Null
    [IO.File]::WriteAllText((Join-Path $Zustand 'abgelehnt.txt'), "$Version $([DateTimeOffset]::Now.ToUnixTimeSeconds())`n", $Utf8)
    [System.Windows.Forms.MessageBox]::Show((T "Das Update auf $Version wurde verschoben. Du wirst in 12 Stunden erneut gefragt.`n`nSofort installieren: Installieren_Windows.bat im Ordner „X-Plane 12\Resources\plugins\P_Profile“ starten." "The update to $Version has been postponed. You will be asked again in 12 hours.`n`nTo install now: start Installieren_Windows.bat in the folder `"X-Plane 12\Resources\plugins\P_Profile`"."), (T 'P_-Profile – Installation' 'P_ Profiles – Installation')) | Out-Null
    exit 2
}

# Abgewähltes Plugin in einer X-KeyPad-Konfiguration unschädlich machen (gleicher Ersatz wie plugins_optional.py):
# Datarefs des Plugins → leer, Kommandos des Plugins → sim/none/none; Groß-/Kleinschreibung egal, führender „/“ mit.
# Reiner Textersatz: der Rest der Datei bleibt unverändert, die Tastenliste lückenlos.
function Neutralisieren([string]$text, $praefixe) {
    $alt = ($praefixe | ForEach-Object { [regex]::Escape($_) }) -join '|'
    $opt = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    $text = [regex]::Replace($text, '("Dataref Name"\s*:\s*)"/?(?:' + $alt + ')[^"]*"', '$1""', $opt)
    return [regex]::Replace($text, '("Name"\s*:\s*)"/?(?:' + $alt + ')[^"]*"', ('$1"' + $LeerKommando + '"'), $opt)
}

function Zeilen($pfad) {
    Get-Content -Encoding UTF8 $pfad | Where-Object { $_.Trim() -ne '' -and -not $_.StartsWith('#') } | ForEach-Object { , $_.Split('|') }
}

# ---------- Auswahlfenster ----------
# Ein Fenster statt mehrerer Dialoge (wie unter macOS): Profile (Häkchen + Status), Zusätze (Lua-Skripte, AeroACARS,
# automatische Updates), Hinweise, „Später/Abbrechen“ und „Installieren“. Hakt man ein neues Profil an, werden die dafür
# nötigen Lua-Skripte mit angehakt.
# $o: Titel, Untertitel, Zeilen (Name, Status, Art = installiert|da|fehlt, An), Lua (Text, An, Fuer = Profil-Indizes),
#     Plugins (Name, An), Aero, Discord, Helfer, Hinweis, Abbrechen, Ok  →  Hashtable Profil/Lua/Plugins (bool-Listen),
#     Aero, Discord, Helfer – oder $null
function AuswahlFenster($o) {
    $schrift = 'Segoe UI'
    $f = New-Object System.Windows.Forms.Form
    $f.Text = (T 'P_-Profile' 'P_ Profiles'); $f.StartPosition = 'CenterScreen'; $f.TopMost = $true
    $f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false; $f.MinimizeBox = $false
    $f.Font = New-Object System.Drawing.Font($schrift, 9)
    function Text($s, $x, $y, $w, $h, $groesse, $fett, $farbe) {
        $l = New-Object System.Windows.Forms.Label
        $l.Text = $s; $l.SetBounds($x, $y, $w, $h); $l.AutoSize = $false
        $stil = $(if ($fett) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular })
        $l.Font = New-Object System.Drawing.Font($schrift, $groesse, $stil)
        if ($farbe) { $l.ForeColor = $farbe }
        $f.Controls.Add($l)
    }
    $grau = [System.Drawing.Color]::DimGray
    $farbe = @{ installiert = [System.Drawing.Color]::FromArgb(30, 140, 60); da = [System.Drawing.Color]::FromArgb(0, 100, 200); fehlt = [System.Drawing.Color]::Gray }

    Text $o.Titel 20 14 560 28 13 $true $null
    Text $o.Untertitel 20 44 560 20 9 $false $grau
    $y = 74
    Text (T 'Profile' 'Profiles') 20 $y 200 18 8 $true $grau; $y += 20
    $lv = New-Object System.Windows.Forms.ListView
    $lv.View = 'Details'; $lv.CheckBoxes = $true; $lv.FullRowSelect = $true; $lv.HeaderStyle = 'None'
    $lv.SetBounds(20, $y, 560, 280)
    [void]$lv.Columns.Add('Profil', 370); [void]$lv.Columns.Add('Status', 165)
    foreach ($z in $o.Zeilen) {
        $it = New-Object System.Windows.Forms.ListViewItem($z.Name)
        $it.UseItemStyleForSubItems = $false
        $sub = $it.SubItems.Add($z.Status); $sub.ForeColor = $farbe[$z.Art]
        $it.Checked = [bool]$z.An
        [void]$lv.Items.Add($it)
    }
    $f.Controls.Add($lv); $y += 288
    $alle = New-Object System.Windows.Forms.Button; $alle.Text = (T 'Alle vorhandenen' 'All found'); $alle.SetBounds(20, $y, 140, 28)
    $nur = New-Object System.Windows.Forms.Button; $nur.Text = (T 'Nur installierte' 'Installed only'); $nur.SetBounds(166, $y, 130, 28)
    $f.Controls.AddRange(@($alle, $nur)); $y += 40

    # Plugins: je eines ein Häkchen, drei pro Reihe
    Text (T 'Plugins in X-Plane (abgewählt: ihre Tasten werden weggelassen)' 'Plugins in X-Plane (unticked: their keys are left out)') 20 $y 560 18 8 $true $grau; $y += 20
    $pluginKasten = @()
    for ($i = 0; $i -lt $o.Plugins.Count; $i++) {
        $k = New-Object System.Windows.Forms.CheckBox; $k.Text = $o.Plugins[$i].Name; $k.Checked = [bool]$o.Plugins[$i].An
        $k.SetBounds((20 + ($i % 3) * 187), ($y + [math]::Floor($i / 3) * 24), 180, 22)
        $f.Controls.Add($k); $pluginKasten += $k
    }
    $y += [math]::Ceiling($o.Plugins.Count / 3) * 24 + 10

    Text (T 'Zusätze' 'Extras') 20 $y 200 18 8 $true $grau; $y += 20
    $luaKasten = @()
    foreach ($l in $o.Lua) {
        $k = New-Object System.Windows.Forms.CheckBox; $k.Text = $l.Text; $k.Checked = [bool]$l.An; $k.SetBounds(20, $y, 560, 22)
        $f.Controls.Add($k); $luaKasten += $k; $y += 24
    }
    $aero = New-Object System.Windows.Forms.CheckBox; $aero.Text = (T 'AeroACARS-Kacheln anzeigen (Startseite XL, Reihe 4)' 'Show AeroACARS tiles (XL start page, row 4)')
    $aero.Checked = [bool]$o.Aero; $aero.SetBounds(20, $y, 560, 22); $f.Controls.Add($aero); $y += 24
    $discord = New-Object System.Windows.Forms.CheckBox; $discord.Text = (T 'Discord-Tasten STUMM/TAUB anzeigen (Startseite XL, oben rechts)' 'Show Discord keys MUTE/DEAF (XL start page, top right)')
    $discord.Checked = [bool]$o.Discord; $discord.SetBounds(20, $y, 560, 22); $f.Controls.Add($discord); $y += 24
    $helfer = New-Object System.Windows.Forms.CheckBox; $helfer.Text = (T 'Automatische Updates (Fenster öffnet sich nach jedem Update von selbst)' 'Automatic updates (this window opens by itself after every update)')
    $helfer.Checked = [bool]$o.Helfer; $helfer.SetBounds(20, $y, 560, 22); $f.Controls.Add($helfer); $y += 32
    if ($o.Hinweis) { Text $o.Hinweis 20 $y 560 20 9 $false ([System.Drawing.Color]::DarkOrange); $y += 24 }
    Text (T 'Stream Deck wird dafür kurz neu gestartet; ersetzte Dateien werden vorher gesichert.' 'Stream Deck is restarted briefly; replaced files are backed up first.') 20 $y 560 18 8 $false $grau
    $y += 30
    $ab = New-Object System.Windows.Forms.Button; $ab.Text = $o.Abbrechen; $ab.SetBounds(330, $y, 120, 30); $ab.DialogResult = 'Cancel'
    $ok = New-Object System.Windows.Forms.Button; $ok.Text = $o.Ok; $ok.SetBounds(460, $y, 120, 30); $ok.DialogResult = 'OK'
    $f.Controls.AddRange(@($ab, $ok)); $f.AcceptButton = $ok; $f.CancelButton = $ab
    $f.ClientSize = New-Object System.Drawing.Size(600, ($y + 46))

    # Lua-Skripte für neu angehakte Profile mit anhaken; Schnellwahl-Knöpfe
    $zeilen = $o.Zeilen; $lua = $o.Lua
    $nachziehen = {
        for ($j = 0; $j -lt $lua.Count; $j++) {
            foreach ($i in $lua[$j].Fuer) { if ($lv.Items[$i].Checked -and $zeilen[$i].Art -ne 'installiert') { $luaKasten[$j].Checked = $true } }
        }
    }.GetNewClosure()
    $lv.Add_ItemChecked($nachziehen)
    $alle.Add_Click({ for ($i = 0; $i -lt $zeilen.Count; $i++) { if ($zeilen[$i].Art -ne 'fehlt') { $lv.Items[$i].Checked = $true } } }.GetNewClosure())
    $nur.Add_Click({ for ($i = 0; $i -lt $zeilen.Count; $i++) { $lv.Items[$i].Checked = ($zeilen[$i].Art -eq 'installiert') } }.GetNewClosure())

    if ($f.ShowDialog() -ne 'OK') { return $null }
    return @{ Profil = @(for ($i = 0; $i -lt $lv.Items.Count; $i++) { $lv.Items[$i].Checked })
              Lua = @($luaKasten | ForEach-Object { $_.Checked }); Plugins = @($pluginKasten | ForEach-Object { $_.Checked })
              Aero = $aero.Checked; Discord = $discord.Checked; Helfer = $helfer.Checked }
}

# Sicherung: Kopie unter $Sicherung\<Pfad ohne Laufwerk>, Originalpfad in inhalt.txt
function Sichern($pfad) {
    if (Test-Path $pfad) {
        $rel = ($pfad -replace '^[A-Za-z]:', '').TrimStart('\')
        $ziel = Join-Path $Sicherung $rel
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ziel) | Out-Null
        Copy-Item -Recurse -Force $pfad $ziel
        [IO.File]::AppendAllText((Join-Path $Sicherung 'inhalt.txt'), "$rel|$pfad`r`n", $Utf8)
    }
}

# Originale: beim ersten Ersetzen eine fremde (eigene) Datei dauerhaft ablegen bzw. merken, dass es keine gab
$Original = Join-Path $Zustand 'Original'
$DateiListe = Join-Path $Zustand 'dateien.txt'
$Register = [ordered]@{}
if (Test-Path $DateiListe) { foreach ($z in @(Zeilen $DateiListe)) { $Register[$z[1]] = $z[0] } }
function OriginalPfad($pfad) { Join-Path $Original ($pfad -replace ':', '') }
function OriginalMerken($pfad, $istP) {
    if ($Register.Contains($pfad)) { return }
    if (-not (Test-Path $pfad)) { $Register[$pfad] = 'neu' }
    elseif ($istP) { $Register[$pfad] = 'p' }
    else {
        $op = OriginalPfad $pfad
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $op) | Out-Null
        Copy-Item -Force $pfad $op
        $Register[$pfad] = 'ersetzt'
    }
}
function RegisterSchreiben {
    New-Item -ItemType Directory -Force -Path $Zustand | Out-Null
    $t = "# Art | Pfad (ersetzt = Original unter Original\, neu = gab es vorher nicht, p = war schon P_)`r`n"
    foreach ($k in $Register.Keys) { $t += "$($Register[$k])|$k`r`n" }
    [IO.File]::WriteAllText($DateiListe, $t, $Utf8)
}
# steht in jeder X-KeyPad-Konfiguration der P_-Profile
function IstPKonfig($pfad) { (Test-Path $pfad) -and (Select-String -Path $pfad -SimpleMatch 'Einheitlicher Tastensatz STD' -Quiet) }

# Stream-Deck-Software beenden und sicher warten, bis der Prozess weg ist (sonst schreibt sie alte Profile zurück)
$script:sdExe = $null
function StreamDeckBeenden {
    $script:sdExe = (Get-Process -Name 'StreamDeck' -ErrorAction SilentlyContinue | Select-Object -First 1).Path
    if (-not $script:sdExe) { $script:sdExe = Join-Path $env:ProgramFiles 'Elgato\StreamDeck\StreamDeck.exe' }
    Get-Process -Name 'StreamDeck' -ErrorAction SilentlyContinue | Stop-Process -Force
    for ($i = 0; $i -lt 40 -and (Get-Process -Name 'StreamDeck' -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Milliseconds 250 }
    Start-Sleep -Seconds 3
}

function JsonLesen($p) { [IO.File]::ReadAllText($p, $Utf8) | ConvertFrom-Json }
function JsonSchreiben($p, $o) { [IO.File]::WriteAllText($p, (ConvertTo-Json -InputObject $o -Depth 100), $Utf8) }

# Startseite eines XL-Profils: Ordner und Manifest; Tasten einer Seite
function Startseite($wurzel) {
    $m = JsonLesen (Join-Path $wurzel 'manifest.json')
    $ordner = Join-Path $wurzel ('Profiles\' + $m.Pages.Pages[0].ToUpper())
    return @($ordner, (JsonLesen (Join-Path $ordner 'manifest.json')))
}
function Tasten($pm) { ($pm.Controllers | Where-Object { $_.Type -eq 'Keypad' } | Select-Object -First 1).Actions }
function XPlaneLaeuft { [bool](Get-Process -Name 'X-Plane' -ErrorAction SilentlyContinue) }

Write-Host '================================================================'
Write-Host " P_-Profile / P_ Profiles – X-Plane 12 – $Version$(if ($Aktualisieren) { ' (Update)' })"
Write-Host '================================================================'

# ---------- 0. Sprache ----------
$SprachDatei = Join-Path $Zustand 'sprache.txt'
if (Test-Path $SprachDatei) { $script:DE = ((Get-Content $SprachDatei -Raw).Trim() -eq 'de') }
if (-not $Aktualisieren) {
    $sf = New-Object System.Windows.Forms.Form
    $sf.Text = 'P_-Profile / P_ Profiles'; $sf.StartPosition = 'CenterScreen'; $sf.TopMost = $true
    $sf.FormBorderStyle = 'FixedDialog'; $sf.MaximizeBox = $false; $sf.MinimizeBox = $false; $sf.ClientSize = New-Object System.Drawing.Size(420, 110)
    $sl = New-Object System.Windows.Forms.Label; $sl.Text = "Sprache für Installer und Tastentexte wählen.`nChoose the language for the installer and key labels."
    $sl.SetBounds(16, 14, 390, 40); $sf.Controls.Add($sl)
    $bd = New-Object System.Windows.Forms.Button; $bd.Text = 'Deutsch'; $bd.SetBounds(196, 64, 100, 30); $bd.DialogResult = 'Yes'
    $be = New-Object System.Windows.Forms.Button; $be.Text = 'English'; $be.SetBounds(304, 64, 100, 30); $be.DialogResult = 'No'
    $sf.Controls.AddRange(@($bd, $be)); $sf.AcceptButton = $(if ($script:DE) { $bd } else { $be })
    $script:DE = ($sf.ShowDialog() -eq 'Yes')
}
$Sprache = $(if ($script:DE) { 'de' } else { 'en' })

# ---------- 1. Voraussetzungen ----------
if (-not $Aktualisieren -and (XPlaneLaeuft)) {
    Abbruch (T 'X-Plane läuft noch. Bitte X-Plane beenden und den Installer erneut starten.' 'X-Plane is still running. Please quit X-Plane and start the installer again.')
}
# Ordner über dem Paket: <X-Plane>\Resources\plugins (neu) oder <X-Plane> selbst (ältere Versionen)
$oben = Split-Path -Parent $Hier
$uebrPlugins = $(if ($oben -match '\\Resources\\plugins\\?$') { Split-Path -Parent (Split-Path -Parent $oben) } else { '' })
$XP = $(if (Test-Path (Join-Path $oben 'Aircraft')) { $oben } elseif ($uebrPlugins -and (Test-Path (Join-Path $uebrPlugins 'Aircraft'))) { $uebrPlugins } else { 'C:\X-Plane 12' })
if (-not (Test-Path (Join-Path $XP 'Aircraft'))) {
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = (T 'Bitte den X-Plane-12-Ordner wählen (enthält Aircraft und Resources)' 'Please choose the X-Plane 12 folder (contains Aircraft and Resources)')
    if ($dlg.ShowDialog() -eq 'OK') { $XP = $dlg.SelectedPath }
}
if (-not (Test-Path (Join-Path $XP 'Aircraft'))) { Abbruch (T 'Kein gültiger X-Plane-Ordner (Aircraft fehlt).' 'Not a valid X-Plane folder (Aircraft missing).') }
Write-Host ((T 'X-Plane-Ordner: ' 'X-Plane folder: ') + $XP)

# ---------- Paketdaten ----------
$Profile = @(Zeilen (Join-Path $Hier 'StreamDeck\profile.txt') | ForEach-Object { [pscustomobject]@{ Kurz = $_[0]; Name = $_[1]; XL = $_[2]; Plus = $_[3] } })
$Zuordnung = @(Zeilen (Join-Path $Hier 'X-Plane\zuordnung.txt') | ForEach-Object { [pscustomobject]@{ Kurz = $_[0]; Acf = $_[1]; AcfName = $_[2]; Konfig = $_[3]; Kamera = $_[4] } })
$Lua = @(Zeilen (Join-Path $Hier 'X-Plane\FlyWithLua\lua.txt') | ForEach-Object { [pscustomobject]@{ Datei = $_[0]; Text = (T $_[1] $_[2]); Fuer = $_[3].Split(',') } })
$Skripte = Join-Path $XP 'Resources\plugins\FlyWithLua\Scripts'
# optionale Plugins und je Profil die X-KeyPad-Tasten, die sie brauchen („Profil|Plugin“ → Tastennamen)
$PluginDatei = Join-Path $Hier 'X-Plane\plugins.txt'
$Plugins = @(if (Test-Path $PluginDatei) { Zeilen $PluginDatei | ForEach-Object { [pscustomobject]@{ Kurz = $_[0]; Ordner = $_[1]; Praefixe = $_[2].Split(','); Name = $_[3] } } })
$PluginTasten = @{}
$TastenDatei = Join-Path $Hier 'X-Plane\plugin_tasten.txt'
if (Test-Path $TastenDatei) { foreach ($z in @(Zeilen $TastenDatei)) { $PluginTasten[$z[0] + '|' + $z[1]] = $z[2].Split("`t") } }
function Installiert($id) { Test-Path (Join-Path $SdProfile ($id.ToUpper() + '.sdProfile')) }

# ---------- Wiederherstellen ----------
if ($Wiederherstellen) {
    if (XPlaneLaeuft) { Abbruch (T 'X-Plane läuft noch. Bitte X-Plane beenden und erneut starten.' 'X-Plane is still running. Please quit X-Plane and start again.') }
    $titelW = (T 'P_-Profile – Wiederherstellen' 'P_ Profiles – Restore')
    # Sicherungen: von Hand (Dokumente) und aus Updates, neueste zuerst
    $sicherungen = @(@(Get-ChildItem ([Environment]::GetFolderPath('MyDocuments')) -Directory -Filter 'P_Profile_Sicherung_*' -ErrorAction SilentlyContinue) +
                     @(Get-ChildItem (Join-Path $Zustand 'Sicherungen') -Directory -ErrorAction SilentlyContinue) |
                     Sort-Object { $_.Name -replace '^.*?(\d{4}-\d\d-\d\d_\d{6})$', '$1' } -Descending)
    $nOrig = @($Register.Values | Where-Object { $_ -eq 'ersetzt' -or $_ -eq 'neu' }).Count
    $eintraege = @()
    if ($nOrig) { $eintraege += (T 'Originalzustand vor den P_-Profilen' 'Original state before the P_ Profiles') }
    foreach ($x in $sicherungen) {
        $zeit = $x.Name -replace '^.*?(\d{4}-\d\d-\d\d)_(\d\d)(\d\d)\d\d$', '$1 $2:$3'
        $eintraege += (T 'Sicherung vom ' 'Backup of ') + $zeit + $(if ($x.FullName -like '*\Sicherungen\*') { T ' (Update)' ' (update)' } else { '' })
    }
    if (-not $eintraege) { Abbruch (T 'Keine Sicherung gefunden.' 'No backup found.') }
    $f = New-Object System.Windows.Forms.Form
    $f.Text = $titelW; $f.StartPosition = 'CenterScreen'; $f.TopMost = $true; $f.FormBorderStyle = 'FixedDialog'
    $f.ClientSize = New-Object System.Drawing.Size(460, 330); $f.MaximizeBox = $false; $f.MinimizeBox = $false
    $l = New-Object System.Windows.Forms.Label; $l.Text = (T 'Was soll wiederhergestellt werden? Der aktuelle Stand wird vorher gesichert.' 'What should be restored? The current state is backed up first.')
    $l.SetBounds(14, 10, 430, 36); $f.Controls.Add($l)
    $lb = New-Object System.Windows.Forms.ListBox; $lb.SetBounds(14, 50, 430, 220); [void]$lb.Items.AddRange([object[]]$eintraege); $lb.SelectedIndex = 0; $f.Controls.Add($lb)
    $ab = New-Object System.Windows.Forms.Button; $ab.Text = (T 'Abbrechen' 'Cancel'); $ab.SetBounds(214, 284, 110, 30); $ab.DialogResult = 'Cancel'
    $ok = New-Object System.Windows.Forms.Button; $ok.Text = (T 'Wiederherstellen' 'Restore'); $ok.SetBounds(334, 284, 110, 30); $ok.DialogResult = 'OK'
    $f.Controls.AddRange(@($ab, $ok)); $f.AcceptButton = $ok; $f.CancelButton = $ab
    if ($f.ShowDialog() -ne 'OK') { Abbruch (T 'Abgebrochen.' 'Cancelled.') }
    $wahl = $lb.SelectedIndex
    function Frage($text) { [System.Windows.Forms.MessageBox]::Show($text, $titelW, 'YesNo') -eq 'Yes' }
    $n = 0; $sdNeu = $false
    if ($nOrig -and $wahl -eq 0) {
        # Originalzustand: eigene Dateien zurück, von den P_-Profilen neu angelegte Dateien entfernen (vorher gesichert)
        foreach ($pfad in @($Register.Keys)) {
            $art = $Register[$pfad]
            if ($art -eq 'ersetzt' -and (Test-Path (OriginalPfad $pfad))) { Sichern $pfad; Copy-Item -Force (OriginalPfad $pfad) $pfad; $n++; $Register.Remove($pfad) }
            elseif ($art -eq 'neu') { if (Test-Path $pfad) { Sichern $pfad; Remove-Item -Force $pfad; $n++ }; $Register.Remove($pfad) }
        }
        RegisterSchreiben
        Write-Host ("  OK $n " + (T 'Dateien auf den Originalzustand gesetzt.' 'files set to the original state.'))
        if (Frage (T 'Auch die P_-Profile aus der Stream-Deck-Software entfernen und automatische Updates abschalten?' 'Also remove the P_ profiles from the Stream Deck software and turn off automatic updates?')) {
            StreamDeckBeenden; Sichern $SdProfile
            foreach ($p in $Profile) { foreach ($id in @($p.XL, $p.Plus)) { Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $SdProfile ($id.ToUpper() + '.sdProfile')) } }
            Unregister-ScheduledTask -TaskName $Aufgabe -Confirm:$false -ErrorAction SilentlyContinue
            Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $Zustand 'update_helfer.ps1'), (Join-Path $Zustand 'installiert.txt')
            Write-Host (T '  OK P_-Profile entfernt, automatische Updates aus.' '  OK P_ profiles removed, automatic updates off.')
            $sdNeu = $true
        }
    } else {
        # Sicherung: Dateien an ihren Originalpfad zurück; den Stream-Deck-Profilordner nur auf Nachfrage
        $quelle = $sicherungen[$wahl - $(if ($nOrig) { 1 } else { 0 })].FullName
        $sdRel = ($SdProfile -replace '^[A-Za-z]:', '').TrimStart('\')
        $liste = @()
        $inhalt = Join-Path $quelle 'inhalt.txt'
        if (Test-Path $inhalt) { $liste = @(Zeilen $inhalt) }
        else {                                    # ältere Sicherung ohne inhalt.txt: Pfade aus dem Ordneraufbau
            $laufwerke = @(Get-PSDrive -PSProvider FileSystem | ForEach-Object { $_.Root.TrimEnd('\') })
            foreach ($d in Get-ChildItem $quelle -Recurse -File) {
                $rel = $d.FullName.Substring($quelle.Length).TrimStart('\')
                if ($rel.StartsWith($sdRel + '\')) { continue }
                $lw = @($laufwerke | Where-Object { Test-Path (Split-Path -Parent (Join-Path $_ $rel)) } | Select-Object -First 1)
                if ($lw) { $liste += , @($rel, (Join-Path $lw[0] $rel)) }
            }
            if (Test-Path (Join-Path $quelle $sdRel)) { $liste += , @($sdRel, $SdProfile) }
        }
        $gesehen = @{}
        foreach ($e in $liste) {
            $rel, $pfad = $e[0], $e[1]
            if ($gesehen.ContainsKey($pfad) -or -not (Test-Path (Join-Path $quelle $rel))) { continue }
            $gesehen[$pfad] = $true
            if ($pfad -eq $SdProfile) {
                if (-not (Frage (T 'Diese Sicherung enthält auch die Stream-Deck-Profile. Alle Stream-Deck-Profile auf diesen Stand zurücksetzen? (Spätere Änderungen an eigenen Profilen gehen dabei verloren.)' 'This backup also contains the Stream Deck profiles. Reset all Stream Deck profiles to this state? (Later changes to your own profiles are lost.)'))) { continue }
                StreamDeckBeenden; Sichern $SdProfile
                Remove-Item -Recurse -Force $SdProfile
                Copy-Item -Recurse -Force (Join-Path $quelle $rel) $SdProfile
                $sdNeu = $true; $n++
                continue
            }
            Sichern $pfad
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $pfad) | Out-Null
            Copy-Item -Force (Join-Path $quelle $rel) $pfad
            $n++
        }
        Write-Host ("  OK $n " + (T 'Einträge wiederhergestellt aus ' 'entries restored from ') + $quelle)
    }
    if ($sdNeu) { if ($script:sdExe -and (Test-Path $script:sdExe)) { Start-Process $script:sdExe } else { Write-Host (T 'Bitte die Stream-Deck-Software jetzt von Hand starten.' 'Please start the Stream Deck software manually now.') } }
    [System.Windows.Forms.MessageBox]::Show((T "Wiederherstellen abgeschlossen ($n Einträge).`n`nDer Stand davor ist gesichert unter:`n" "Restore complete ($n entries).`n`nThe previous state is backed up in:`n") + $Sicherung, $titelW) | Out-Null
    exit 0
}
function HatPlugin($id, $uuid) {
    try { $a = Tasten (Startseite (Join-Path $SdProfile ($id.ToUpper() + '.sdProfile')))[1]
          return [bool]($a.PSObject.Properties | Where-Object { $_.Value.Plugin.UUID -eq $uuid }) }
    catch { return $false }
}
function HatAero($id) { HatPlugin $id $AeroAcars }

# Flugzeugordner je .acf (bis 4 Ebenen tief); bei gleichem .acf-Namen entscheidet „P acf/_name“
$Funde = @{}
function AcfOrdner($z) {
    if (-not $Funde.ContainsKey($z.Acf)) {
        $Funde[$z.Acf] = @(Get-ChildItem -Path (Join-Path $XP 'Aircraft') -Filter ($z.Acf + '.acf') -Recurse -Depth 3 -File -ErrorAction SilentlyContinue)
    }
    @($Funde[$z.Acf] | Where-Object { -not $z.AcfName -or (Select-String -Path $_.FullName -Pattern ('^P acf/_name ' + [regex]::Escape($z.AcfName) + '\s*$') -Quiet) } | ForEach-Object { $_.DirectoryName })
}
function FlugzeugDa($kurz) { @($Zuordnung | Where-Object { $_.Kurz -eq $kurz } | ForEach-Object { AcfOrdner $_ }).Count -gt 0 }

# ---------- 2.–5. Auswahl im Fenster: Profile, Lua-Skripte, AeroACARS, automatische Updates ----------
$StatusText = @{ installiert = (T 'installiert' 'installed'); da = (T 'Flugzeug vorhanden' 'aircraft found'); fehlt = (T 'Flugzeug nicht gefunden' 'aircraft not found') }
$Zeilen = @(foreach ($p in $Profile) {
    $art = $(if (Installiert $p.XL) { 'installiert' } elseif (FlugzeugDa $p.Kurz) { 'da' } else { 'fehlt' })
    # vorbelegt: installierte; außerhalb des Update-Modus auch alle, deren Flugzeug gefunden wird
    [pscustomobject]@{ Name = $p.Name; Art = $art; Status = $StatusText[$art]; An = ($art -eq 'installiert' -or (-not $Aktualisieren -and $art -eq 'da')) }
})
$LuaZeilen = @(foreach ($l in $Lua) {
    $fuer = @(for ($i = 0; $i -lt $Profile.Count; $i++) { if ($l.Fuer -contains $Profile[$i].Kurz) { $i } })
    # vorbelegt: für vorbelegte Profile nötig (Update-Modus: für neu gewählte) und – im Update-Modus – bereits installiert
    $an = ($Aktualisieren -and (Test-Path (Join-Path $Skripte $l.Datei))) -or [bool]@($fuer | Where-Object { $Zeilen[$_].An -and -not ($Aktualisieren -and $Zeilen[$_].Art -eq 'installiert') }).Count
    [pscustomobject]@{ Text = ($l.Datei + ' – ' + $l.Text); An = $an; Fuer = $fuer }
})
$nInst = @($Zeilen | Where-Object { $_.Art -eq 'installiert' }).Count
$nNeu = @($Zeilen | Where-Object { $_.Art -eq 'da' }).Count
$AeroVor = $(if ($nInst) { [bool](@($Profile | Where-Object { (Installiert $_.XL) -and (HatAero $_.XL) }).Count) } else { $true })
# Discord: bisherige Wahl; ohne installierte P_-Profile: Discord-Plugin der Stream-Deck-Software vorhanden
$DiscordVor = $(if ($nInst) { [bool](@($Profile | Where-Object { (Installiert $_.XL) -and (HatPlugin $_.XL $Discord) }).Count) }
                else { Test-Path (Join-Path (Split-Path -Parent $SdProfile) "Plugins\$Discord.sdPlugin") })
# Plugins vorbelegt: Update-Modus mit gemerkter Wahl → diese, sonst Ordner in Resources\plugins vorhanden
$Gemerkt = @{}
$GemerktDatei = Join-Path $Zustand 'plugins.txt'
if (Test-Path $GemerktDatei) { foreach ($z in Get-Content -Encoding UTF8 $GemerktDatei) { $kv = $z.Split('='); if ($kv.Count -eq 2) { $Gemerkt[$kv[0].Trim()] = ($kv[1].Trim() -eq '1') } } }
$PluginZeilen = @(foreach ($pl in $Plugins) {
    $an = $(if ($Aktualisieren -and $Gemerkt.ContainsKey($pl.Kurz)) { $Gemerkt[$pl.Kurz] } else { Test-Path (Join-Path $XP ('Resources\plugins\' + $pl.Ordner)) })
    [pscustomobject]@{ Name = $pl.Name; An = $an }
})
$AltVersion = $(if (Test-Path (Join-Path $Zustand 'installiert.txt')) { (Get-Content (Join-Path $Zustand 'installiert.txt') -Raw).Trim() } else { '–' })
$Fenster = @{
    Titel = $(if ($Aktualisieren) { T "Version $Version ist bereit" "Version $Version is ready" } else { T "P_-Profile $Version installieren" "Install P_ Profiles $Version" })
    Untertitel = $(if ($Aktualisieren) { T "Installiert: $AltVersion · $nInst von $($Profile.Count) Profilen auf diesem PC" "Installed: $AltVersion · $nInst of $($Profile.Count) profiles on this PC" } else { T "$nInst Profile installiert · $nNeu weitere Flugzeuge in X-Plane gefunden" "$nInst profiles installed · $nNeu more aircraft found in X-Plane" })
    Zeilen = $Zeilen; Lua = $LuaZeilen; Plugins = $PluginZeilen; Aero = $AeroVor; Discord = $DiscordVor; Helfer = $true
    Hinweis = $(if ($Aktualisieren -and (XPlaneLaeuft)) { T 'X-Plane läuft gerade – die Installation startet von selbst, sobald X-Plane beendet ist.' 'X-Plane is running – the installation starts by itself as soon as X-Plane has been quit.' } else { '' })
    Abbrechen = $(if ($Aktualisieren) { T 'Später' 'Later' } else { T 'Abbrechen' 'Cancel' }); Ok = (T 'Installieren' 'Install')
}
$Auswahl = AuswahlFenster $Fenster
if ($null -eq $Auswahl) { if ($Aktualisieren) { Spaeter } else { Abbruch (T 'Abgebrochen.' 'Cancelled.') } }
$Gewaehlt = @(for ($i = 0; $i -lt $Profile.Count; $i++) { if ($Auswahl.Profil[$i]) { $Profile[$i] } })
$LuaGewaehlt = @(for ($j = 0; $j -lt $Lua.Count; $j++) { if ($Auswahl.Lua[$j]) { $Lua[$j] } })
$Aero = [bool]$Auswahl.Aero
$MitDiscord = [bool]$Auswahl.Discord
$Helfer = [bool]$Auswahl.Helfer
$PluginsAus = @(for ($i = 0; $i -lt $Plugins.Count; $i++) { if (-not $Auswahl.Plugins[$i]) { $Plugins[$i] } })
$OhneKamera = [bool]@($PluginsAus | Where-Object { $_.Kurz -eq 'xc' }).Count
Write-Host ('Plugins: ' + (@(for ($i = 0; $i -lt $Plugins.Count; $i++) { $Plugins[$i].Name + $(if ($Auswahl.Plugins[$i]) { ' OK' } else { ' –' }) }) -join ' · '))

# Update-Modus: nie bei laufendem X-Plane in die Stream-Deck-Software eingreifen – warten, bis X-Plane beendet ist
if ($Aktualisieren -and (XPlaneLaeuft)) {
    Write-Host (T 'Warte, bis X-Plane beendet ist …' 'Waiting for X-Plane to quit …')
    while (XPlaneLaeuft) { Start-Sleep -Seconds 15 }
    Start-Sleep -Seconds 5
}

# ---------- 6. Flugzeugdateien ----------
Write-Host (T "`nFlugzeugdateien:" "`nAircraft files:")
foreach ($p in $Gewaehlt) {
    foreach ($z in @($Zuordnung | Where-Object { $_.Kurz -eq $p.Kurz })) {
        $ordner = @(AcfOrdner $z)
        if (-not $ordner) { Write-Host ('  – ' + $z.Acf + (T ': Flugzeug nicht gefunden, übersprungen' ': aircraft not found, skipped')); continue }
        foreach ($o in $ordner) {
            $pOrdner = IstPKonfig (Join-Path $o (Split-Path -Leaf $z.Konfig.Replace('/', '\')))   # hatte schon P_-Dateien
            foreach ($d in @(if ($OhneKamera) { $z.Konfig } else { $z.Konfig; $z.Kamera })) {
                $quelle = Join-Path $Hier ('X-Plane\Aircraft\' + $d.Replace('/', '\'))
                $zielDatei = Join-Path $o (Split-Path -Leaf $quelle)
                OriginalMerken $zielDatei $pOrdner
                Sichern $zielDatei
                if ($d -eq $z.Konfig -and $PluginsAus.Count) {
                    # Konfiguration mit unschädlich gemachten Tasten der abgewählten Plugins schreiben
                    $t = [IO.File]::ReadAllText($quelle, $Utf8)
                    foreach ($pl in $PluginsAus) { $t = Neutralisieren $t $pl.Praefixe }
                    [IO.File]::WriteAllText($zielDatei, $t, $Utf8)
                } else { Copy-Item -Force $quelle $o }
            }
            Write-Host "  OK $($z.Acf) -> $($o.Substring($XP.Length + 1))"
        }
    }
}

# ---------- Lua ----------
if ($LuaGewaehlt) {
    if (-not (Test-Path $Skripte)) { Write-Host (T '  FlyWithLua ist nicht installiert – Skripte übersprungen.' '  FlyWithLua is not installed – scripts skipped.') }
    else {
        foreach ($l in $LuaGewaehlt) {
            OriginalMerken (Join-Path $Skripte $l.Datei) $true       # P_*.lua sind immer Dateien der P_-Profile
            Sichern (Join-Path $Skripte $l.Datei)
            Copy-Item -Force (Join-Path $Hier ('X-Plane\FlyWithLua\Scripts\' + $l.Datei)) $Skripte
            Write-Host "  OK $($l.Datei)"
        }
    }
}

RegisterSchreiben

# ---------- 7. Stream Deck ----------
if (-not (Test-Path $SdProfile)) { Abbruch (T 'Stream-Deck-Profilordner nicht gefunden. Bitte die Stream-Deck-Software installieren, einmal mit angeschlossenen Geräten starten und den Installer erneut ausführen.' 'Stream Deck profile folder not found. Please install the Stream Deck software, start it once with the devices connected and run the installer again.') }
$geraet = @{}
foreach ($d in Get-ChildItem $SdProfile -Directory -Filter '*.sdProfile') {
    try {
        $m = JsonLesen (Join-Path $d.FullName 'manifest.json')
        if ($m.Device.Model -and $m.Device.UUID -and -not $m.Device.UUID.Contains('P0PROFIL') -and -not $geraet.ContainsKey($m.Device.Model)) { $geraet[$m.Device.Model] = $m.Device.UUID }
    } catch {}
}
if ($geraet[$ModellXL]) { Write-Host (T 'Stream Deck XL erkannt.' 'Stream Deck XL found.') } else { Write-Host (T 'Kein Stream Deck XL – XL-Profile übersprungen.' 'No Stream Deck XL – XL profiles skipped.') }
if ($geraet[$ModellPlus]) { Write-Host (T 'Stream Deck + erkannt.' 'Stream Deck + found.') } else { Write-Host (T 'Kein Stream Deck + – Plus-Profile übersprungen.' 'No Stream Deck + – Plus profiles skipped.') }

StreamDeckBeenden
$sdExe = $script:sdExe
Sichern $SdProfile

# Stream-Deck-Tasten, die auf X-KeyPad-Tasten abgewählter Plugins zeigen, aus allen Seiten eines Profils entfernen
# (auch in Mehrfachaktionen); danach Ordner-Tasten, deren Seite dadurch nur noch die Zurück-Taste hat (wiederholt,
# bis sich nichts mehr ändert). Der Platz bleibt leer.
function Trifft($a, $weg) {
    if ($null -eq $a) { return $false }
    if ($a.Settings -and $a.Settings.KeyName -and $weg.Contains([string]$a.Settings.KeyName)) { return $true }
    foreach ($b in @($a.Actions)) { if ($b -is [pscustomobject] -and (Trifft $b $weg)) { return $true } }
    return $false
}
function Aktionen($pm) {
    foreach ($c in @($pm.Controllers)) { if ($c.Actions) { foreach ($pr in @($c.Actions.PSObject.Properties)) { , @($c, $pr.Name, $pr.Value) } } }
}
function PluginTastenEntfernen($wurzel, $weg) {
    $seiten = @{}
    foreach ($d in Get-ChildItem (Join-Path $wurzel 'Profiles') -Directory) {
        $mf = Join-Path $d.FullName 'manifest.json'
        if (Test-Path $mf) { $seiten[$d.Name.ToUpper()] = @{ Mf = $mf; Pm = (JsonLesen $mf); Geaendert = $false; Geleert = $false } }
    }
    foreach ($s in $seiten.Values) {
        foreach ($e in @(Aktionen $s.Pm)) { if (Trifft $e[2] $weg) { $e[0].Actions.PSObject.Properties.Remove($e[1]); $s.Geaendert = $true } }
    }
    do {
        $runde = $false
        foreach ($s in $seiten.Values) {
            if ($s.Geaendert -and -not $s.Geleert -and -not @(Aktionen $s.Pm | Where-Object { $_[2].UUID -ne $Zurueck }).Count) { $s.Geleert = $true }
        }
        foreach ($s in $seiten.Values) {
            foreach ($e in @(Aktionen $s.Pm)) {
                if ($e[2].UUID -eq $OrdnerAktion -and $e[2].Settings) {
                    $kind = $seiten[([string]$e[2].Settings.ProfileUUID).ToUpper()]
                    if ($kind -and $kind.Geleert) { $e[0].Actions.PSObject.Properties.Remove($e[1]); $s.Geaendert = $true; $runde = $true }
                }
            }
        }
    } while ($runde)
    foreach ($s in $seiten.Values) { if ($s.Geaendert) { JsonSchreiben $s.Mf $s.Pm } }
}

$xlId = $(if ($geraet[$ModellXL]) { $geraet[$ModellXL] } else { $PlatzXL })
$plusId = $(if ($geraet[$ModellPlus]) { $geraet[$ModellPlus] } else { $PlatzPlus })
$n = 0
foreach ($p in $Gewaehlt) {
    foreach ($paar in @(@($p.XL, $ModellXL), @($p.Plus, $ModellPlus))) {
        if (-not $geraet[$paar[1]]) { continue }
        $name = $paar[0].ToUpper() + '.sdProfile'
        $ziel = Join-Path $SdProfile $name
        if (Test-Path $ziel) { Remove-Item -Recurse -Force $ziel }
        Copy-Item -Recurse (Join-Path $Hier "StreamDeck\Profile\$name") $ziel
        foreach ($mf in Get-ChildItem $ziel -Recurse -Filter 'manifest.json') {
            $t = [IO.File]::ReadAllText($mf.FullName, $Utf8).Replace($PlatzXL, $xlId).Replace($PlatzPlus, $plusId)
            [IO.File]::WriteAllText($mf.FullName, $t, $Utf8)
        }
        $weg = New-Object 'System.Collections.Generic.HashSet[string]'
        foreach ($pl in $PluginsAus) { foreach ($k in @($PluginTasten[$p.Kurz + '|' + $pl.Kurz])) { if ($k) { [void]$weg.Add($k) } } }
        if ($weg.Count) { PluginTastenEntfernen $ziel $weg }
        $n++
    }
}
Write-Host ("  OK $n " + (T 'Profile installiert.' 'profiles installed.'))

# Kreis: alle installierten P_-Profile in Paket-Reihenfolge, Zurück = 0,0, Vor = 2,0; AeroACARS anwenden
$kreis = @($Profile | Where-Object { Installiert $_.XL })
for ($i = 0; $i -lt $kreis.Count; $i++) {
    $wurzel = Join-Path $SdProfile ($kreis[$i].XL.ToUpper() + '.sdProfile')
    $ordner, $pm = Startseite $wurzel
    $a = Tasten $pm
    foreach ($paar in @(@('0,0', $kreis[($i - 1 + $kreis.Count) % $kreis.Count]), @('2,0', $kreis[($i + 1) % $kreis.Count]))) {
        $t = $a.($paar[0])
        if ($t -and $t.Actions -and $t.Actions[0].Actions -and @($t.Actions[0].Actions).Count -ge 2) {
            $t.Actions[0].Actions[0].Settings.ProfileUUID = $paar[1].XL
            $t.Actions[0].Actions[1].Settings.ProfileUUID = $paar[1].Plus
        }
    }
    # AeroACARS und Discord: anzeigen = Tasten aus dem Paket übernehmen (Bilder in den Seitenordner), ausblenden = entfernen
    $quelle = Join-Path $Hier ('StreamDeck\Profile\' + $kreis[$i].XL.ToUpper() + '.sdProfile')
    foreach ($paar in @(@($AeroAcars, $Aero), @($Discord, $MitDiscord))) {
        foreach ($pos in @($a.PSObject.Properties | Where-Object { $_.Value.Plugin.UUID -eq $paar[0] } | ForEach-Object { $_.Name })) { $a.PSObject.Properties.Remove($pos) }
        if ($paar[1] -and (Test-Path $quelle)) {
            $qOrdner, $qpm = Startseite $quelle
            $qa = Tasten $qpm
            foreach ($pr in @($qa.PSObject.Properties | Where-Object { $_.Value.Plugin.UUID -eq $paar[0] })) {
                $a | Add-Member -NotePropertyName $pr.Name -NotePropertyValue $pr.Value -Force
                foreach ($st in @($pr.Value.States)) {
                    if ($st.Image -and -not (Test-Path (Join-Path $ordner $st.Image))) {
                        New-Item -ItemType Directory -Force -Path (Join-Path $ordner 'Images') | Out-Null
                        Copy-Item -Force (Join-Path $qOrdner $st.Image) (Join-Path $ordner $st.Image)
                    }
                }
            }
        }
    }
    JsonSchreiben (Join-Path $ordner 'manifest.json') $pm
}
Write-Host ((T '  OK Kreis Vor/Zurück: ' '  OK next/previous circle: ') + (($kreis | ForEach-Object { $_.Name }) -join ' -> '))

# Sprache der Tastentexte auf alle installierten P_-Profile anwenden (XL und Plus, alle Seiten): Bilder der Rollen
# ZURÜCK (Kreis = prev, Unterseite = back), VOR, STUMM, TAUB auf die Datei der gewählten Sprache umstellen.
$Rolle = @{}
foreach ($spr in $SprachBild.Keys) { foreach ($r in $SprachBild[$spr].Keys) { $Rolle[$SprachBild[$spr][$r]] = $r } }
$nSprache = 0
foreach ($p in $Profile) {
    foreach ($id in @($p.XL, $p.Plus)) {
        $seitenOrdner = Join-Path $SdProfile ($id.ToUpper() + '.sdProfile\Profiles')
        if (-not (Test-Path $seitenOrdner)) { continue }
        foreach ($d in Get-ChildItem $seitenOrdner -Directory) {
            $mf = Join-Path $d.FullName 'manifest.json'
            if (-not (Test-Path $mf)) { continue }
            $pm = JsonLesen $mf
            $geaendert = $false
            foreach ($c in @($pm.Controllers)) {
                if (-not $c.Actions) { continue }
                foreach ($pr in @($c.Actions.PSObject.Properties)) {
                    foreach ($st in @($pr.Value.States)) {
                        if (-not $st -or -not $st.Image) { continue }
                        $datei = $st.Image -replace '^Images/', ''
                        if (-not $Rolle.ContainsKey($datei)) { continue }
                        $r = $Rolle[$datei]
                        if ($r -eq 'prev' -or $r -eq 'back') { $r = $(if ($pr.Value.UUID -eq 'com.elgato.streamdeck.profile.backtoparent') { 'back' } else { 'prev' }) }
                        $neu = $SprachBild[$Sprache][$r]
                        $zielBild = Join-Path $d.FullName ('Images\' + $neu)
                        if (-not (Test-Path $zielBild)) {
                            New-Item -ItemType Directory -Force -Path (Join-Path $d.FullName 'Images') | Out-Null
                            Copy-Item -Force (Join-Path $Hier "StreamDeck\Sprache\$Sprache\$neu") $zielBild
                        }
                        if ($st.Image -ne "Images/$neu") { $st.Image = "Images/$neu"; $geaendert = $true }
                    }
                }
            }
            if ($geaendert) { JsonSchreiben $mf $pm; $nSprache++ }
        }
    }
}
Write-Host ((T '  OK Tastentexte: Deutsch' '  OK key labels: English') + " ($nSprache" + (T ' Seiten umgestellt)' ' pages changed)'))

# ---------- 8. Installierte Version merken, Update-Helfer ----------
New-Item -ItemType Directory -Force -Path $Zustand | Out-Null
[IO.File]::WriteAllText((Join-Path $Zustand 'installiert.txt'), "$Version`n", $Utf8)
[IO.File]::WriteAllText($SprachDatei, "$Sprache`n", $Utf8)
if ($Plugins.Count) {
    $merk = @(for ($i = 0; $i -lt $Plugins.Count; $i++) { $Plugins[$i].Kurz + '=' + $(if ($Auswahl.Plugins[$i]) { '1' } else { '0' }) }) -join "`n"
    [IO.File]::WriteAllText($GemerktDatei, "$merk`n", $Utf8)
}
Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $Zustand 'abgelehnt.txt')
$helferSkript = Join-Path $Zustand 'update_helfer.ps1'
if ($Helfer -and (Test-Path (Join-Path $Hier 'StreamDeck\update_helfer.ps1'))) { Copy-Item -Force (Join-Path $Hier 'StreamDeck\update_helfer.ps1') $helferSkript }
if (-not $Aktualisieren) {
    try {
        Unregister-ScheduledTask -TaskName $Aufgabe -Confirm:$false -ErrorAction SilentlyContinue
        if ($Helfer) {
            $aktion = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$helferSkript`" `"$XP`""
            $ausloeser = @((New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME),
                           (New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 30)))
            $einst = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero)
            Register-ScheduledTask -TaskName $Aufgabe -Action $aktion -Trigger $ausloeser -Settings $einst -Force | Out-Null
            Write-Host (T '  OK Automatische Updates eingerichtet.' '  OK Automatic updates set up.')
        } else {
            Remove-Item -Force -ErrorAction SilentlyContinue $helferSkript
            Write-Host (T '  – Automatische Updates: aus.' '  – Automatic updates: off.')
        }
    } catch {
        Write-Host ((T '  Automatische Updates konnten nicht eingerichtet werden: ' '  Automatic updates could not be set up: ') + $_.Exception.Message)
    }
}
# Update-Modus: nur die letzten drei Sicherungen behalten
if ($Aktualisieren) {
    Get-ChildItem (Join-Path $Zustand 'Sicherungen') -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -Skip 3 | Remove-Item -Recurse -Force
}

# ---------- 9. Ordner P_Profile nach Resources\plugins ----------
$NeuerOrt = Join-Path $XP 'Resources\plugins\P_Profile'
if ($Hier.TrimEnd('\') -eq (Join-Path $XP 'P_Profile') -and (Test-Path (Join-Path $XP 'Resources\plugins'))) {
    try {
        Set-Location $env:TEMP; [Environment]::CurrentDirectory = $env:TEMP   # Ordner darf nicht Arbeitsordner sein
        if (Test-Path $NeuerOrt) {
            New-Item -ItemType Directory -Force -Path $Sicherung | Out-Null
            Move-Item -Force $NeuerOrt (Join-Path $Sicherung 'P_Profile_plugins_alt')
        }
        Move-Item $Hier.TrimEnd('\') $NeuerOrt
        Write-Host ((T '  OK Ordner P_Profile verschoben nach ' '  OK folder P_Profile moved to ') + $NeuerOrt)
    } catch {
        Write-Host ((T '  Ordner P_Profile konnte nicht verschoben werden: ' '  Folder P_Profile could not be moved: ') + $_.Exception.Message)
    }
}

if (Test-Path $sdExe) { Start-Process $sdExe } else { Write-Host (T 'Bitte die Stream-Deck-Software jetzt von Hand starten.' 'Please start the Stream Deck software manually now.') }
Write-Host ((T "`nFertig. Sicherung: " "`nDone. Backup: ") + $Sicherung)
$fertig = $(if ($Aktualisieren) { T "Update auf $Version installiert." "Update to $Version installed." } else { T 'Installation abgeschlossen.' 'Installation complete.' })
[System.Windows.Forms.MessageBox]::Show($fertig + (T "`n`nSicherung der ersetzten Dateien:`n" "`n`nBackup of replaced files:`n") + $Sicherung, (T 'P_-Profile' 'P_ Profiles')) | Out-Null
# Update-Modus, automatische Updates abgewählt: geplante Aufgabe und Helfer entfernen (als letzte Aktion)
if ($Aktualisieren -and -not $Helfer) {
    Unregister-ScheduledTask -TaskName $Aufgabe -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -Force -ErrorAction SilentlyContinue $helferSkript
}
