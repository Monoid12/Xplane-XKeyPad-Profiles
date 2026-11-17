# P_-Profile für X-Plane 12 – Installation unter Windows (PowerShell 5.1 oder neuer)
#
# Gleicher Ablauf wie der macOS-Installer (StreamDeck/installer_macos.js):
#   1. Prüfen: X-Plane beendet (im Update-Modus: warten, bis X-Plane beendet ist), X-Plane-Ordner (der Ordner über
#      P_Profile, sonst Standard C:\X-Plane 12, sonst Auswahl).
#   2. Auswahl der Profile (Häkchenliste). Vorbelegt: bereits installierte P_-Profile und Profile, deren Flugzeug im
#      Aircraft-Ordner gefunden wird (Update-Modus: nur die installierten). Ein erneuter Aufruf installiert weitere nach.
#   3. Auswahl der FlyWithLua-Skripte (optional, vorbelegt: die für die gewählten Flugzeuge nötigen; Update-Modus:
#      zusätzlich die bereits installierten).
#   4. AeroACARS-Kacheln (Startseite XL, Reihe 4, 7 Tasten) anzeigen oder ausblenden (Update-Modus: bisherige Wahl).
#   5. Automatische Updates: Update-Helfer (geplante Aufgabe „P_Profile Update“) einrichten oder entfernen.
#   6. Flugzeugdateien (X-KeyPad-Konfiguration, X-Camera-Sichten) neben die passende .acf-Datei kopieren.
#   7. Stream-Deck-Profile nach %APPDATA%\Elgato\StreamDeck\ProfilesV3 (Geräte-Platzhalter → eigene Geräte), danach
#      Vor/Zurück aller installierten P_-Profile im Kreis neu verknüpfen und die AeroACARS-Wahl auf alle anwenden.
#   8. Installierte Version merken (%LOCALAPPDATA%\P_Profile\installiert.txt).
# Update-Modus (Schalter -Aktualisieren): vom Update-Helfer (update_helfer.ps1) gestartet, sobald der SkunkCrafts
# Updater im Ordner X-Plane 12\P_Profile eine neuere Version abgelegt hat. „Später“ merkt Version und Zeitpunkt in
# abgelehnt.txt; der Helfer fragt nach 12 Stunden erneut.
# Vorhandene Dateien werden vorher nach Dokumente\P_Profile_Sicherung_<Zeitstempel>\ gesichert, im Update-Modus nach
# %LOCALAPPDATA%\P_Profile\Sicherungen\<Zeitstempel>\ (die letzten drei bleiben).
# Start über Installieren_Windows.bat (umgeht die Ausführungsrichtlinie nur für dieses Skript).
param([switch]$Aktualisieren)

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
$Aufgabe = 'P_Profile Update'
$Utf8 = New-Object System.Text.UTF8Encoding $false
$DE = (Get-Culture).TwoLetterISOLanguageName -eq 'de'
function T($de, $en) { if ($DE) { $de } else { $en } }
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
    [System.Windows.Forms.MessageBox]::Show((T "Das Update auf $Version wurde verschoben. Du wirst in 12 Stunden erneut gefragt.`n`nSofort installieren: Installieren_Windows.bat im Ordner „P_Profile“ starten." "The update to $Version has been postponed. You will be asked again in 12 hours.`n`nTo install now: start Installieren_Windows.bat in the folder `"P_Profile`"."), (T 'P_-Profile – Installation' 'P_ Profiles – Installation')) | Out-Null
    exit 2
}

function Zeilen($pfad) {
    Get-Content -Encoding UTF8 $pfad | Where-Object { $_.Trim() -ne '' -and -not $_.StartsWith('#') } | ForEach-Object { , $_.Split('|') }
}

# Häkchenliste: gibt die Indizes der angehakten Einträge zurück ($null bei Abbruch)
function Auswahl($titel, $text, $eintraege, $vorbelegt, $abbrechenText) {
    $f = New-Object System.Windows.Forms.Form
    $f.Text = $titel; $f.Width = 620; $f.Height = 560; $f.StartPosition = 'CenterScreen'; $f.TopMost = $true
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.Left = 10; $l.Top = 10; $l.Width = 585; $l.Height = 48
    $c = New-Object System.Windows.Forms.CheckedListBox
    $c.Left = 10; $c.Top = 62; $c.Width = 585; $c.Height = 400; $c.CheckOnClick = $true
    for ($i = 0; $i -lt $eintraege.Count; $i++) { [void]$c.Items.Add($eintraege[$i], ($vorbelegt -contains $i)) }
    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'OK'; $ok.Left = 410; $ok.Top = 475; $ok.DialogResult = 'OK'
    $ab = New-Object System.Windows.Forms.Button
    $ab.Text = $(if ($abbrechenText) { $abbrechenText } else { T 'Abbrechen' 'Cancel' }); $ab.Left = 500; $ab.Top = 475; $ab.DialogResult = 'Cancel'
    $f.Controls.AddRange(@($l, $c, $ok, $ab)); $f.AcceptButton = $ok; $f.CancelButton = $ab
    if ($f.ShowDialog() -ne 'OK') { return $null }
    return @($c.CheckedIndices | ForEach-Object { [int]$_ })
}

function Sichern($pfad) {
    if (Test-Path $pfad) {
        $rel = ($pfad -replace '^[A-Za-z]:', '').TrimStart('\')
        $ziel = Join-Path $Sicherung $rel
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ziel) | Out-Null
        Copy-Item -Recurse -Force $pfad $ziel
    }
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

# ---------- 1. Voraussetzungen ----------
if (-not $Aktualisieren -and (XPlaneLaeuft)) {
    Abbruch (T 'X-Plane läuft noch. Bitte X-Plane beenden und den Installer erneut starten.' 'X-Plane is still running. Please quit X-Plane and start the installer again.')
}
$oben = Split-Path -Parent $Hier          # Ordner über dem Paket (P_Profile im X-Plane-Hauptordner)
$XP = $(if (Test-Path (Join-Path $oben 'Aircraft')) { $oben } else { 'C:\X-Plane 12' })
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
function Installiert($id) { Test-Path (Join-Path $SdProfile ($id.ToUpper() + '.sdProfile')) }
function HatAero($id) {
    try { $a = Tasten (Startseite (Join-Path $SdProfile ($id.ToUpper() + '.sdProfile')))[1]
          return [bool]($a.PSObject.Properties | Where-Object { $_.Value.Plugin.UUID -eq $AeroAcars }) }
    catch { return $false }
}

# Flugzeugordner je .acf (bis 4 Ebenen tief); bei gleichem .acf-Namen entscheidet „P acf/_name“
$Funde = @{}
function AcfOrdner($z) {
    if (-not $Funde.ContainsKey($z.Acf)) {
        $Funde[$z.Acf] = @(Get-ChildItem -Path (Join-Path $XP 'Aircraft') -Filter ($z.Acf + '.acf') -Recurse -Depth 3 -File -ErrorAction SilentlyContinue)
    }
    @($Funde[$z.Acf] | Where-Object { -not $z.AcfName -or (Select-String -Path $_.FullName -Pattern ('^P acf/_name ' + [regex]::Escape($z.AcfName) + '\s*$') -Quiet) } | ForEach-Object { $_.DirectoryName })
}
function FlugzeugDa($kurz) { @($Zuordnung | Where-Object { $_.Kurz -eq $kurz } | ForEach-Object { AcfOrdner $_ }).Count -gt 0 }

# ---------- 2. Profile ----------
$liste = @(); $vor = @()
for ($i = 0; $i -lt $Profile.Count; $i++) {
    $p = $Profile[$i]
    if (Installiert $p.XL) { $liste += $p.Name + (T '  (installiert)' '  (installed)'); $vor += $i }
    elseif (FlugzeugDa $p.Kurz) {
        if ($Aktualisieren) { $liste += $p.Name + (T '  (Flugzeug vorhanden)' '  (aircraft found)') } else { $liste += $p.Name; $vor += $i }
    }
    else { $liste += $p.Name + (T '  (Flugzeug nicht gefunden)' '  (aircraft not found)') }
}
if ($Aktualisieren) {
    $wahl = Auswahl ((T 'P_-Profile – Update auf ' 'P_ Profiles – update to ') + $Version) (T "Neue Version $Version. Angehakt sind deine installierten Profile – sie werden aktualisiert. Weitere Profile kannst du dazunehmen." "New version $Version. Your installed profiles are ticked and will be updated. You can add more profiles.") $liste $vor (T 'Später' 'Later')
    if ($null -eq $wahl) { Spaeter }
} else {
    $wahl = Auswahl (T 'P_-Profile – Profile wählen' 'P_ Profiles – choose profiles') (T 'Welche Profile sollen installiert bzw. aktualisiert werden? Bereits installierte, hier abgewählte Profile bleiben unverändert.' 'Which profiles should be installed or updated? Installed profiles that are not selected here stay unchanged.') $liste $vor
    if ($null -eq $wahl) { Abbruch (T 'Abgebrochen.' 'Cancelled.') }
}
$Gewaehlt = @($wahl | ForEach-Object { $Profile[$_] })

# ---------- 3. Lua ----------
$luaListe = @($Lua | ForEach-Object { $_.Datei + ' – ' + $_.Text })
$luaVor = @()
for ($i = 0; $i -lt $Lua.Count; $i++) {
    $noetig = $Gewaehlt | Where-Object { $Lua[$i].Fuer -contains $_.Kurz -and -not ($Aktualisieren -and (Installiert $_.XL)) }
    if ($noetig -or ($Aktualisieren -and (Test-Path (Join-Path $Skripte $Lua[$i].Datei)))) { $luaVor += $i }
}
$lw = Auswahl (T 'P_-Profile – FlyWithLua-Skripte' 'P_ Profiles – FlyWithLua scripts') (T 'Welche FlyWithLua-Skripte sollen installiert werden? (optional; vorbelegt: für die gewählten Flugzeuge nötig bzw. bereits installiert)' 'Which FlyWithLua scripts should be installed? (optional; preselected: required for the chosen aircraft or already installed)') $luaListe $luaVor
$LuaGewaehlt = @(); if ($lw) { $LuaGewaehlt = @($lw | ForEach-Object { $Lua[$_] }) }

# ---------- 4. AeroACARS ----------
if ($Aktualisieren) {
    $Aero = [bool](@($Profile | Where-Object { (Installiert $_.XL) -and (HatAero $_.XL) }).Count)
} else {
    $antw = [System.Windows.Forms.MessageBox]::Show((T "AeroACARS-Kacheln (Startseite des Stream Deck XL, Reihe 4, 7 Tasten) anzeigen?`n`nSie funktionieren nur mit dem AeroACARS-Plugin für Piloten der German Sky Group. Bei „Nein“ bleiben die Plätze leer. Die Wahl gilt für alle installierten P_-Profile." "Show the AeroACARS tiles (Stream Deck XL start page, row 4, 7 keys)?`n`nThey only work with the AeroACARS plugin for German Sky Group pilots. With `"No`" the keys stay empty. The choice applies to all installed P_ profiles."), 'AeroACARS', 'YesNo')
    $Aero = $antw -eq 'Yes'
}

# ---------- 5. Automatische Updates ----------
if ($Aktualisieren) { $Helfer = $true } else {
    $antw = [System.Windows.Forms.MessageBox]::Show((T "Updates automatisch einspielen?`n`nLiegt dieser Ordner als „P_Profile“ im X-Plane-12-Hauptordner und bringt ihn der SkunkCrafts Updater auf eine neue Version, öffnet sich danach von selbst ein Fenster mit deinen Profilen; nach „OK“ wird alles eingespielt. Dafür wird eine geplante Aufgabe „$Aufgabe“ eingerichtet (bei der Anmeldung und alle 30 Minuten).`n`nOhne Helfer: nach jedem Update diesen Installer erneut starten." "Install updates automatically?`n`nIf this folder sits as `"P_Profile`" in the X-Plane 12 main folder and the SkunkCrafts Updater brings it to a new version, a window with your profiles opens by itself afterwards; after `"OK`" everything is installed. A scheduled task `"$Aufgabe`" is set up for this (at logon and every 30 minutes).`n`nWithout the helper: run this installer again after every update."), (T 'Automatische Updates' 'Automatic updates'), 'YesNo')
    $Helfer = $antw -eq 'Yes'
}

$text = (T 'Installieren: ' 'Install: ') + (($Gewaehlt | ForEach-Object { $_.Name }) -join ', ') + "`nLua: " + (($LuaGewaehlt | ForEach-Object { $_.Datei }) -join ', ') + "`nAeroACARS: " + $(if ($Aero) { T 'anzeigen' 'show' } else { T 'ausblenden' 'hide' }) + "`n" + (T 'Automatische Updates: ' 'Automatic updates: ') + $(if ($Helfer) { T 'ja' 'yes' } else { T 'nein' 'no' }) + "`n`n" + (T 'Die Stream-Deck-Software wird dafür kurz beendet und neu gestartet.' 'The Stream Deck software will be quit briefly and restarted.')
if ($Aktualisieren -and (XPlaneLaeuft)) { $text += "`n`n" + (T 'X-Plane läuft gerade – die Installation startet von selbst, sobald X-Plane beendet ist.' 'X-Plane is running – the installation starts by itself as soon as X-Plane has been quit.') }
if ([System.Windows.Forms.MessageBox]::Show($text, (T 'P_-Profile – Installation' 'P_ Profiles – Installation'), 'OKCancel') -ne 'OK') {
    if ($Aktualisieren) { Spaeter } else { Abbruch (T 'Abgebrochen.' 'Cancelled.') }
}

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
            foreach ($d in @($z.Konfig, $z.Kamera)) {
                $quelle = Join-Path $Hier ('X-Plane\Aircraft\' + $d.Replace('/', '\'))
                Sichern (Join-Path $o (Split-Path -Leaf $quelle))
                Copy-Item -Force $quelle $o
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
            Sichern (Join-Path $Skripte $l.Datei)
            Copy-Item -Force (Join-Path $Hier ('X-Plane\FlyWithLua\Scripts\' + $l.Datei)) $Skripte
            Write-Host "  OK $($l.Datei)"
        }
    }
}

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

$sdExe = (Get-Process -Name 'StreamDeck' -ErrorAction SilentlyContinue | Select-Object -First 1).Path
if (-not $sdExe) { $sdExe = Join-Path $env:ProgramFiles 'Elgato\StreamDeck\StreamDeck.exe' }
Get-Process -Name 'StreamDeck' -ErrorAction SilentlyContinue | Stop-Process -Force
# sicher warten, bis der Prozess weg ist – sonst schreibt die Software ihren alten Stand über die neuen Profile
for ($i = 0; $i -lt 40 -and (Get-Process -Name 'StreamDeck' -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Milliseconds 250 }
Start-Sleep -Seconds 3
Sichern $SdProfile
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
    foreach ($pos in @($a.PSObject.Properties | Where-Object { $_.Value.Plugin.UUID -eq $AeroAcars } | ForEach-Object { $_.Name })) { $a.PSObject.Properties.Remove($pos) }
    if ($Aero) {
        $quelle = Join-Path $Hier ('StreamDeck\Profile\' + $kreis[$i].XL.ToUpper() + '.sdProfile')
        if (Test-Path $quelle) {
            $qa = Tasten (Startseite $quelle)[1]
            foreach ($pr in @($qa.PSObject.Properties | Where-Object { $_.Value.Plugin.UUID -eq $AeroAcars })) {
                $a | Add-Member -NotePropertyName $pr.Name -NotePropertyValue $pr.Value -Force
            }
        }
    }
    JsonSchreiben (Join-Path $ordner 'manifest.json') $pm
}
Write-Host ((T '  OK Kreis Vor/Zurück: ' '  OK next/previous circle: ') + (($kreis | ForEach-Object { $_.Name }) -join ' -> '))

# ---------- 8. Installierte Version merken, Update-Helfer ----------
New-Item -ItemType Directory -Force -Path $Zustand | Out-Null
[IO.File]::WriteAllText((Join-Path $Zustand 'installiert.txt'), "$Version`n", $Utf8)
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

if (Test-Path $sdExe) { Start-Process $sdExe } else { Write-Host (T 'Bitte die Stream-Deck-Software jetzt von Hand starten.' 'Please start the Stream Deck software manually now.') }
Write-Host ((T "`nFertig. Sicherung: " "`nDone. Backup: ") + $Sicherung)
$fertig = $(if ($Aktualisieren) { T "Update auf $Version installiert." "Update to $Version installed." } else { T 'Installation abgeschlossen.' 'Installation complete.' })
[System.Windows.Forms.MessageBox]::Show($fertig + (T "`n`nSicherung der ersetzten Dateien:`n" "`n`nBackup of replaced files:`n") + $Sicherung, (T 'P_-Profile' 'P_ Profiles')) | Out-Null
