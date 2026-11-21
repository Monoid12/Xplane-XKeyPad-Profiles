# P_-Profile für X-Plane 12 – Update-Helfer (Windows)
#
# Vom Installer als geplante Aufgabe „P_Profile Update“ eingerichtet (bei der Anmeldung und alle 30 Minuten) und nach
# %LOCALAPPDATA%\P_Profile\update_helfer.ps1 kopiert.
#
# Er startet den Installer im Update-Modus (Fenster mit den Profilen), wenn
#   - im Ordner P_Profile (<X-Plane>\Resources\plugins\P_Profile, bei älteren Installationen <X-Plane>\P_Profile)
#     eine NEUERE Version liegt als die zuletzt installierte (installiert.txt),
#   - der SkunkCrafts Updater fertig ist (Version in skunkcrafts_updater.cfg = VERSION, seit einer Minute keine Änderung),
#   - „Später“ für diese Version nicht vor weniger als 12 Stunden gewählt wurde (abgelehnt.txt),
#   - nicht schon ein Lauf aktiv ist (Mutex).
# Wartet X-Plane noch, übernimmt das der Installer. Protokoll: helfer.log im selben Ordner.
#
# Aufruf: powershell -File update_helfer.ps1 "<X-Plane-Ordner>"
# Abschalten: Installer erneut starten und „Automatische Updates“ mit Nein beantworten.
param([string]$XP)

$PP = Join-Path $XP 'Resources\plugins\P_Profile'
if (-not (Test-Path $PP)) { $PP = Join-Path $XP 'P_Profile' }
$Zustand = Join-Path $env:LOCALAPPDATA 'P_Profile'
$Log = Join-Path $Zustand 'helfer.log'
function Protokoll($text) { New-Item -ItemType Directory -Force -Path $Zustand | Out-Null; Add-Content -Path $Log -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $text" }
function Lesen($p) { if (Test-Path $p) { ((Get-Content $p -Raw) -replace '\s', '') } else { '' } }
# Version vergleichbar machen („3“ → 3.0); unlesbar = 0.0
function V($s) { try { if ($s -notmatch '\.') { $s += '.0' }; [version]$s } catch { [version]'0.0' } }

if (-not $XP -or -not (Test-Path (Join-Path $PP 'VERSION')) -or -not (Test-Path (Join-Path $PP 'Installieren_Windows.ps1'))) { exit 0 }

$neu = Lesen (Join-Path $PP 'VERSION')
$alt = Lesen (Join-Path $Zustand 'installiert.txt')
if (-not $neu -or $neu -eq $alt) { exit 0 }
# nur aufwärts: liegt die installierte Version gleich hoch oder höher, nichts tun
if ($alt -and (V $alt) -ge (V $neu)) { exit 0 }

# „Später“ für diese Version: frühestens nach 12 Stunden erneut fragen
$abg = Join-Path $Zustand 'abgelehnt.txt'
if (Test-Path $abg) {
    $teile = (Get-Content $abg -Raw).Trim().Split(' ')
    if ($teile.Count -ge 2 -and $teile[0] -eq $neu -and ([DateTimeOffset]::Now.ToUnixTimeSeconds() - [long]$teile[1]) -lt 43200) { exit 0 }
}

# Updater fertig? Version in der cfg = VERSION und seit einer Minute keine Datei im Ordner geändert (max. 10 Minuten warten)
for ($i = 1; $i -le 20; $i++) {
    $cfg = ((Select-String -Path (Join-Path $PP 'skunkcrafts_updater.cfg') -Pattern '^version\|' -ErrorAction SilentlyContinue | Select-Object -First 1).Line -replace '^version\|', '').Trim()
    $frisch = Get-ChildItem $PP -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-1) } | Select-Object -First 1
    if ($cfg -eq $neu -and -not $frisch) { break }
    if ($i -eq 20) { Protokoll "Update $alt -> ${neu}: Updater noch nicht fertig – nächster Versuch später"; exit 0 }
    Start-Sleep -Seconds 30
}

# nur ein Lauf zur Zeit
$sperre = New-Object System.Threading.Mutex($false, 'Local\P_Profile_Update')
if (-not $sperre.WaitOne(0)) { exit 0 }
try {
    Protokoll "Update $alt -> ${neu}: Installer startet"
    $p = Start-Process powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$(Join-Path $PP 'Installieren_Windows.ps1')`"", '-Aktualisieren') -Wait -PassThru
    Protokoll "Installer beendet (Status $($p.ExitCode))"
} finally { $sperre.ReleaseMutex() }
