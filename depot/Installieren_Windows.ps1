# P_-Profile für X-Plane 12 – Installation unter Windows (PowerShell 5.1 oder neuer)
#
# Gleicher Ablauf wie der macOS-Installer (StreamDeck/installer_macos.js):
#   1. Prüfen: X-Plane beendet (im Update-Modus: warten, bis X-Plane beendet ist), X-Plane-Ordner (der Ordner über
#      P_Profile, sonst Standard C:\X-Plane 12, sonst Auswahl).
#   2.–5. Ein Fenster mit allen Wahlmöglichkeiten:
#   2. Profile (Häkchen mit Status). Vorbelegt: bereits installierte P_-Profile und Profile, deren Flugzeug im
#      Aircraft-Ordner gefunden wird (Update-Modus: nur die installierten). Ein erneuter Aufruf installiert weitere nach.
#   3. FlyWithLua-Skripte (optional, vorbelegt: die für die gewählten Flugzeuge nötigen; Update-Modus: zusätzlich die
#      bereits installierten; neu angehakte Profile haken ihre nötigen Skripte mit an).
#   4. AeroACARS-Kacheln (Startseite XL, Reihe 4, 7 Tasten) anzeigen oder ausblenden (vorbelegt: bisherige Wahl).
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

# ---------- Auswahlfenster ----------
# Ein Fenster statt mehrerer Dialoge (wie unter macOS): Profile (Häkchen + Status), Zusätze (Lua-Skripte, AeroACARS,
# automatische Updates), Hinweise, „Später/Abbrechen“ und „Installieren“. Hakt man ein neues Profil an, werden die dafür
# nötigen Lua-Skripte mit angehakt.
# $o: Titel, Untertitel, Zeilen (Name, Status, Art = installiert|da|fehlt, An), Lua (Text, An, Fuer = Profil-Indizes),
#     Aero, Helfer, Hinweis, Abbrechen, Ok  →  Hashtable Profil/Lua (bool-Listen), Aero, Helfer – oder $null
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

    Text (T 'Zusätze' 'Extras') 20 $y 200 18 8 $true $grau; $y += 20
    $luaKasten = @()
    foreach ($l in $o.Lua) {
        $k = New-Object System.Windows.Forms.CheckBox; $k.Text = $l.Text; $k.Checked = [bool]$l.An; $k.SetBounds(20, $y, 560, 22)
        $f.Controls.Add($k); $luaKasten += $k; $y += 24
    }
    $aero = New-Object System.Windows.Forms.CheckBox; $aero.Text = (T 'AeroACARS-Kacheln anzeigen (Startseite XL, Reihe 4)' 'Show AeroACARS tiles (XL start page, row 4)')
    $aero.Checked = [bool]$o.Aero; $aero.SetBounds(20, $y, 560, 22); $f.Controls.Add($aero); $y += 24
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
              Lua = @($luaKasten | ForEach-Object { $_.Checked }); Aero = $aero.Checked; Helfer = $helfer.Checked }
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
$AltVersion = $(if (Test-Path (Join-Path $Zustand 'installiert.txt')) { (Get-Content (Join-Path $Zustand 'installiert.txt') -Raw).Trim() } else { '–' })
$Fenster = @{
    Titel = $(if ($Aktualisieren) { T "Version $Version ist bereit" "Version $Version is ready" } else { T "P_-Profile $Version installieren" "Install P_ Profiles $Version" })
    Untertitel = $(if ($Aktualisieren) { T "Installiert: $AltVersion · $nInst von $($Profile.Count) Profilen auf diesem PC" "Installed: $AltVersion · $nInst of $($Profile.Count) profiles on this PC" } else { T "$nInst Profile installiert · $nNeu weitere Flugzeuge in X-Plane gefunden" "$nInst profiles installed · $nNeu more aircraft found in X-Plane" })
    Zeilen = $Zeilen; Lua = $LuaZeilen; Aero = $AeroVor; Helfer = $true
    Hinweis = $(if ($Aktualisieren -and (XPlaneLaeuft)) { T 'X-Plane läuft gerade – die Installation startet von selbst, sobald X-Plane beendet ist.' 'X-Plane is running – the installation starts by itself as soon as X-Plane has been quit.' } else { '' })
    Abbrechen = $(if ($Aktualisieren) { T 'Später' 'Later' } else { T 'Abbrechen' 'Cancel' }); Ok = (T 'Installieren' 'Install')
}
$Auswahl = AuswahlFenster $Fenster
if ($null -eq $Auswahl) { if ($Aktualisieren) { Spaeter } else { Abbruch (T 'Abgebrochen.' 'Cancelled.') } }
$Gewaehlt = @(for ($i = 0; $i -lt $Profile.Count; $i++) { if ($Auswahl.Profil[$i]) { $Profile[$i] } })
$LuaGewaehlt = @(for ($j = 0; $j -lt $Lua.Count; $j++) { if ($Auswahl.Lua[$j]) { $Lua[$j] } })
$Aero = [bool]$Auswahl.Aero
$Helfer = [bool]$Auswahl.Helfer

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
# Update-Modus, automatische Updates abgewählt: geplante Aufgabe und Helfer entfernen (als letzte Aktion)
if ($Aktualisieren -and -not $Helfer) {
    Unregister-ScheduledTask -TaskName $Aufgabe -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -Force -ErrorAction SilentlyContinue $helferSkript
}
