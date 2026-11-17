// P_-Profile für X-Plane 12 – Installer macOS (JavaScript for Automation, gestartet von Installieren_macOS.command
// oder im Update-Modus vom Update-Helfer)
//
// Ablauf:
//   1. Prüfen: X-Plane beendet (im Update-Modus: warten, bis X-Plane beendet ist), X-Plane-Ordner (der Ordner über
//      P_Profile, sonst Standard ~/X-Plane 12, sonst Auswahl).
//   2. Auswahl der Profile (Mehrfachauswahl). Vorbelegt: bereits installierte P_-Profile und Profile, deren Flugzeug
//      im Aircraft-Ordner gefunden wird (Update-Modus: nur die installierten). Ein erneuter Aufruf installiert weitere
//      Profile nach.
//   3. Auswahl der FlyWithLua-Skripte (optional, vorbelegt: die für die gewählten Flugzeuge nötigen; Update-Modus:
//      zusätzlich die bereits installierten).
//   4. AeroACARS-Kacheln (Startseite XL, Reihe 4, 7 Tasten) anzeigen oder ausblenden (Update-Modus: bisherige Wahl).
//   5. Automatische Updates: Update-Helfer einrichten oder entfernen (Update-Modus: bleibt eingerichtet).
//   6. Flugzeugdateien (X-KeyPad-Konfiguration, X-Camera-Sichten) neben die passende .acf-Datei kopieren.
//   7. Stream-Deck-Profile kopieren (Geräte-Platzhalter → eigene Geräte), danach Vor/Zurück aller installierten
//      P_-Profile im Kreis neu verknüpfen (nur gewählte + bereits installierte) und die AeroACARS-Wahl auf alle
//      installierten P_-Profile anwenden.
//   8. Installierte Version merken (~/Library/Application Support/P_Profile/installiert.txt), Helfer einrichten.
//
// Update-Modus (Argument --aktualisieren): Der Update-Helfer (update_helfer.sh, LaunchAgent com.p-profile.update)
// startet den Installer aus dem Ordner X-Plane 12/P_Profile, sobald der SkunkCrafts Updater dort eine neuere Version
// abgelegt hat. „Später“ merkt Version und Zeitpunkt in abgelehnt.txt; der Helfer fragt nach 12 Stunden erneut.
//
// Jede ersetzte Datei und der Stream-Deck-Profilordner werden vorher gesichert: nach ~/Documents/P_Profile_Sicherung_
// <Zeit>/, im Update-Modus nach ~/Library/Application Support/P_Profile/Sicherungen/<Zeit>/ (die letzten drei bleiben).
// Paketdateien: StreamDeck/profile.txt (Kreisfolge), X-Plane/zuordnung.txt, X-Plane/FlyWithLua/lua.txt,
// StreamDeck/update_helfer.sh.
// Testmodus (nur Entwicklung): Umgebungsvariablen P_TEST_SD (Profilordner), P_TEST_XP (X-Plane-Ordner),
// P_TEST_ZUSTAND (Ordner für Zustand, Helfer und LaunchAgent-Datei), P_TEST_WAHL (Kürzel, kommagetrennt),
// P_TEST_LUA (Dateien, kommagetrennt), P_TEST_AERO (an|aus), P_TEST_HELFER (an|aus) ersetzen Ordner und Dialoge;
// die Stream-Deck-Software wird dann weder beendet noch gestartet, launchctl wird nicht aufgerufen.

ObjC.import('Foundation');
const app = Application.currentApplication();
app.includeStandardAdditions = true;

const DE = (() => { try { return app.doShellScript('defaults read -g AppleLocale').toLowerCase().startsWith('de'); }
                    catch (e) { return true; } })();
const T = (de, en) => (DE ? de : en);
const sh = (cmd) => app.doShellScript(cmd);
const q = (s) => "'" + String(s).replace(/'/g, "'\\''") + "'";
const log = (s) => console.log(s);
const existiert = (p) => $.NSFileManager.defaultManager.fileExistsAtPath(p);
const lesen = (p) => ObjC.unwrap($.NSString.stringWithContentsOfFileEncodingError(p, $.NSUTF8StringEncoding, null));
const schreiben = (p, s) => $(s).writeToFileAtomicallyEncodingError(p, true, $.NSUTF8StringEncoding, null);
const zeilen = (p) => lesen(p).split(/\r?\n/).filter((z) => z.trim() && !z.startsWith('#')).map((z) => z.split('|'));
const xml = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

const MODELL_XL = '20GAT9902', MODELL_PLUS = '20GBD9901';
const PLATZ_XL = '@(1)[4057/143/P0PROFILXL000]', PLATZ_PLUS = '@(1)[4057/132/P0PROFILPLUS0]';
const AEROACARS = 'eu.german-sky-group.aeroacars';
const AGENT = 'com.p-profile.update';            // LaunchAgent des Update-Helfers
const TITEL = T('P_-Profile – Installation', 'P_ Profiles – Installation');

function abbruch(text) {
  app.displayDialog(text, { buttons: ['OK'], defaultButton: 'OK', withIcon: 'stop', withTitle: TITEL });
  throw new Error(text);
}

const umgebung = (n) => { const v = $.NSProcessInfo.processInfo.environment.objectForKey(n); return v.isNil() ? '' : ObjC.unwrap(v); };
const TEST = umgebung('P_TEST_SD') !== '';

function run(argv) {
  const HIER = argv[0];
  const UPDATE = argv.includes('--aktualisieren');
  const HOME = ObjC.unwrap($.NSHomeDirectory());
  const SD = TEST ? umgebung('P_TEST_SD') : HOME + '/Library/Application Support/com.elgato.StreamDeck/ProfilesV3';
  const ZUSTAND = TEST ? umgebung('P_TEST_ZUSTAND') : HOME + '/Library/Application Support/P_Profile';
  const stempel = sh('date +%Y-%m-%d_%H%M%S');
  const SICHERUNG = UPDATE ? ZUSTAND + '/Sicherungen/' + stempel
    : (TEST ? umgebung('P_TEST_XP') + '/..' : HOME + '/Documents') + '/P_Profile_Sicherung_' + stempel;
  const version = existiert(HIER + '/VERSION') ? lesen(HIER + '/VERSION').trim() : '';
  log('================================================================');
  log(' P_-Profile / P_ Profiles – X-Plane 12 – ' + version + (UPDATE ? ' (Update)' : ''));
  log('================================================================');
  if (UPDATE && !TEST) app.activate();            // Dialoge nach vorn (Aufruf aus dem Hintergrund-Helfer)

  // Update-Modus: „Später“ merken (Version, Zeitpunkt) – der Helfer fragt nach 12 Stunden erneut
  function spaeter() {
    sh('mkdir -p ' + q(ZUSTAND));
    schreiben(ZUSTAND + '/abgelehnt.txt', version + ' ' + sh('date +%s') + '\n');
    if (!TEST) app.displayDialog(T('Das Update auf ' + version + ' wurde verschoben. Du wirst in 12 Stunden erneut gefragt.\n\n' +
                                   'Sofort installieren: Installieren_macOS.command im Ordner „P_Profile“ starten.',
                                   'The update to ' + version + ' has been postponed. You will be asked again in 12 hours.\n\n' +
                                   'To install now: start Installieren_macOS.command in the folder “P_Profile”.'),
                                 { buttons: ['OK'], defaultButton: 'OK', withTitle: TITEL });
    throw new Error('später');
  }

  // ---------- 1. Voraussetzungen ----------
  // exakter Prozessname: die Absturz-Wächter von X-Plane („handler --run-after-crash …“) laufen nach dem Beenden weiter
  const xpLaeuft = () => !TEST && sh("pgrep -qx X-Plane && echo ja || echo nein") === 'ja';
  if (!UPDATE && xpLaeuft())
    abbruch(T('X-Plane läuft noch. Bitte X-Plane beenden und den Installer erneut starten.',
              'X-Plane is still running. Please quit X-Plane and start the installer again.'));
  const oben = HIER.replace(/\/[^/]+\/?$/, '');    // Ordner über dem Paket (P_Profile im X-Plane-Hauptordner)
  let XP = TEST ? umgebung('P_TEST_XP') : existiert(oben + '/Aircraft') ? oben : HOME + '/X-Plane 12';
  if (!existiert(XP + '/Aircraft')) {
    try {
      XP = app.chooseFolder({ withPrompt: T('Bitte den X-Plane-12-Ordner wählen (enthält Aircraft und Resources)',
                                           'Please choose the X-Plane 12 folder (contains Aircraft and Resources)') })
             .toString().replace(/\/$/, '');
    } catch (e) { abbruch(T('Kein X-Plane-Ordner gewählt – Abbruch.', 'No X-Plane folder chosen – cancelled.')); }
  }
  if (!existiert(XP + '/Aircraft')) abbruch(T('Kein gültiger X-Plane-Ordner (Aircraft fehlt).', 'Not a valid X-Plane folder (Aircraft missing).'));
  log(T('X-Plane-Ordner: ', 'X-Plane folder: ') + XP);

  // ---------- Paketdaten ----------
  const profile = zeilen(HIER + '/StreamDeck/profile.txt').map(([kurz, name, xl, plus]) => ({ kurz, name, xl, plus }));
  const zuordnung = zeilen(HIER + '/X-Plane/zuordnung.txt').map(([kurz, acf, acfName, konfig, kamera]) =>
    ({ kurz, acf, acfName, konfig, kamera }));
  const lua = zeilen(HIER + '/X-Plane/FlyWithLua/lua.txt').map(([datei, de, en, fuer]) =>
    ({ datei, text: DE ? de : en, fuer: fuer.split(',') }));
  const installiert = (id) => existiert(SD + '/' + id.toUpperCase() + '.sdProfile');
  const SKRIPTE = XP + '/Resources/plugins/FlyWithLua/Scripts';

  // Startseite eines XL-Profils: [Seitenordner, Manifest]; Tasten einer Seite
  function startseite(wurzel) {
    const m = JSON.parse(lesen(wurzel + '/manifest.json'));
    const id = m.Pages.Pages[0].toUpperCase();
    const ordner = wurzel + '/Profiles/' + id;
    return [ordner, JSON.parse(lesen(ordner + '/manifest.json'))];
  }
  const tasten = (pm) => (pm.Controllers.find((c) => c.Type === 'Keypad') || {}).Actions || {};
  const hatAero = (id) => {
    try { return Object.values(tasten(startseite(SD + '/' + id.toUpperCase() + '.sdProfile')[1]))
                       .some((a) => a.Plugin && a.Plugin.UUID === AEROACARS); }
    catch (e) { return false; }
  };

  // Flugzeugdateien je .acf suchen (bis 4 Ebenen tief); bei gleichem .acf-Namen entscheidet „P acf/_name“
  const fundeCache = {};
  function acfOrdner(z) {
    if (!(z.acf in fundeCache)) {
      const out = sh('find ' + q(XP + '/Aircraft') + ' -maxdepth 4 -name ' + q(z.acf + '.acf') + ' -type f 2>/dev/null || true');
      fundeCache[z.acf] = out ? out.split('\r').join('\n').split('\n').filter(Boolean) : [];
    }
    return fundeCache[z.acf].filter((f) => !z.acfName ||
      sh('grep -a -c -x ' + q('P acf/_name ' + z.acfName) + ' ' + q(f) + ' || true') !== '0')
      .map((f) => f.replace(/\/[^/]+$/, ''));
  }
  const flugzeugDa = (kurz) => zuordnung.some((z) => z.kurz === kurz && acfOrdner(z).length);

  // ---------- 2. Auswahl der Profile ----------
  const eintrag = (p) => p.name + (installiert(p.xl) ? T('  (installiert)', '  (installed)') :
                                    flugzeugDa(p.kurz) ? (UPDATE ? T('  (Flugzeug vorhanden)', '  (aircraft found)') : '') :
                                    T('  (Flugzeug nicht gefunden)', '  (aircraft not found)'));
  const liste = profile.map(eintrag);
  const vorbelegt = profile.filter((p) => installiert(p.xl) || (!UPDATE && flugzeugDa(p.kurz))).map(eintrag);
  const wahl = TEST ? profile.filter((p) => umgebung('P_TEST_WAHL').split(',').includes(p.kurz)).map(eintrag) :
    app.chooseFromList(liste, {
    withTitle: UPDATE ? T('P_-Profile – Update auf ', 'P_ Profiles – update to ') + version
                      : T('P_-Profile – Profile wählen', 'P_ Profiles – choose profiles'),
    withPrompt: UPDATE
      ? T('Neue Version ' + version + '. Angehakt sind deine installierten Profile – sie werden aktualisiert. ' +
          'Weitere Profile kannst du mit ⌘-Klick dazunehmen.',
          'New version ' + version + '. Your installed profiles are ticked and will be updated. ' +
          'You can add more profiles with ⌘-click.')
      : T('Welche Profile sollen installiert bzw. aktualisiert werden? (Mehrfachauswahl mit ⌘)\n' +
          'Bereits installierte, hier abgewählte Profile bleiben unverändert.',
          'Which profiles should be installed or updated? (multiple selection with ⌘)\n' +
          'Installed profiles that are not selected here stay unchanged.'),
    okButtonName: T('Weiter', 'Next'), cancelButtonName: UPDATE ? T('Später', 'Later') : T('Abbrechen', 'Cancel'),
    defaultItems: vorbelegt, multipleSelectionsAllowed: true, emptySelectionAllowed: true });
  if (wahl === false) { if (UPDATE) spaeter(); abbruch(T('Abgebrochen.', 'Cancelled.')); }
  const gewaehlt = profile.filter((p) => wahl.includes(eintrag(p)));

  // ---------- 3. Lua-Skripte ----------
  const luaText = (l) => l.datei + ' – ' + l.text;
  const luaDa = (l) => existiert(SKRIPTE + '/' + l.datei);
  const luaListe = lua.map(luaText);
  const luaVor = lua.filter((l) => gewaehlt.some((p) => l.fuer.includes(p.kurz) && !(UPDATE && installiert(p.xl))) ||
                                   (UPDATE && luaDa(l))).map(luaText);
  const luaWahl = TEST ? lua.filter((l) => umgebung('P_TEST_LUA').split(',').includes(l.datei)).map(luaText) :
    app.chooseFromList(luaListe, {
    withTitle: T('P_-Profile – FlyWithLua-Skripte', 'P_ Profiles – FlyWithLua scripts'),
    withPrompt: UPDATE
      ? T('FlyWithLua-Skripte (optional; vorbelegt: bereits installierte und für neu gewählte Flugzeuge nötige)',
          'FlyWithLua scripts (optional; preselected: already installed and required for newly chosen aircraft)')
      : T('Welche FlyWithLua-Skripte sollen installiert werden? (optional; vorbelegt: für die gewählten Flugzeuge nötig)',
          'Which FlyWithLua scripts should be installed? (optional; preselected: required for the chosen aircraft)'),
    defaultItems: luaVor, multipleSelectionsAllowed: true, emptySelectionAllowed: true });
  const luaGewaehlt = luaWahl === false ? [] : lua.filter((l) => luaWahl.includes(luaText(l)));

  // ---------- 4. AeroACARS ----------
  const knopfAn = T('Anzeigen', 'Show'), knopfAus = T('Ausblenden', 'Hide');
  const aero = TEST ? umgebung('P_TEST_AERO') === 'an'
    : UPDATE ? profile.some((p) => installiert(p.xl) && hatAero(p.xl))
    : app.displayDialog(T('AeroACARS-Kacheln (Startseite des Stream Deck XL, Reihe 4, 7 Tasten) anzeigen?\n' +
                          'Sie funktionieren nur mit dem AeroACARS-Plugin für Piloten der German Sky Group. ' +
                          'Ausgeblendet bleiben die Plätze leer. Die Wahl gilt für alle installierten P_-Profile.',
                          'Show the AeroACARS tiles (Stream Deck XL start page, row 4, 7 keys)?\n' +
                          'They only work with the AeroACARS plugin for German Sky Group pilots. When hidden, ' +
                          'the keys stay empty. The choice applies to all installed P_ profiles.'),
                        { buttons: [knopfAus, knopfAn], defaultButton: knopfAn,
                          withTitle: 'AeroACARS' }).buttonReturned === knopfAn;

  // ---------- 5. Automatische Updates ----------
  const ja = T('Ja', 'Yes'), nein = T('Nein', 'No');
  const helfer = UPDATE ? true : TEST ? umgebung('P_TEST_HELFER') === 'an'
    : app.displayDialog(T('Updates automatisch einspielen?\n\nLiegt dieser Ordner als „P_Profile“ im X-Plane-12-Hauptordner ' +
                          'und bringt ihn der SkunkCrafts Updater auf eine neue Version, öffnet sich danach von selbst ' +
                          'ein Fenster mit deinen Profilen; nach „Installieren“ wird alles eingespielt. Dafür wird ein ' +
                          'kleiner Hintergrund-Helfer eingerichtet (macOS meldet einmalig „Hintergrundobjekt hinzugefügt“).\n\n' +
                          'Ohne Helfer: nach jedem Update diesen Installer erneut starten.',
                          'Install updates automatically?\n\nIf this folder sits as “P_Profile” in the X-Plane 12 main ' +
                          'folder and the SkunkCrafts Updater brings it to a new version, a window with your profiles ' +
                          'opens by itself afterwards; after “Install” everything is installed. A small background helper ' +
                          'is set up for this (macOS reports “Background item added” once).\n\n' +
                          'Without the helper: run this installer again after every update.'),
                        { buttons: [nein, ja], defaultButton: ja, withTitle: T('Automatische Updates', 'Automatic updates') })
        .buttonReturned === ja;

  if (!TEST) {
    try {
      app.displayDialog(
        T('Installieren:\n• ', 'Install:\n• ') + (gewaehlt.map((p) => p.name).join(', ') || T('keine Profile', 'no profiles')) +
        T('\n• Lua: ', '\n• Lua: ') + (luaGewaehlt.map((l) => l.datei).join(', ') || '–') +
        '\n• AeroACARS: ' + (aero ? knopfAn : knopfAus) +
        T('\n• Automatische Updates: ', '\n• Automatic updates: ') + (helfer ? ja : nein) +
        T('\n\nDie Stream-Deck-Software wird dafür kurz beendet und neu gestartet.',
          '\n\nThe Stream Deck software will be quit briefly and restarted.') +
        (UPDATE && xpLaeuft() ? T('\n\nX-Plane läuft gerade – die Installation startet von selbst, sobald X-Plane beendet ist.',
                                  '\n\nX-Plane is running – the installation starts by itself as soon as X-Plane has been quit.') : ''),
        { buttons: [UPDATE ? T('Später', 'Later') : T('Abbrechen', 'Cancel'), T('Installieren', 'Install')],
          defaultButton: T('Installieren', 'Install'),
          cancelButton: UPDATE ? T('Später', 'Later') : T('Abbrechen', 'Cancel'), withTitle: TITEL });
    } catch (e) { if (UPDATE) spaeter(); throw e; }
  }

  // Update-Modus: nie bei laufendem X-Plane in die Stream-Deck-Software eingreifen – warten, bis X-Plane beendet ist
  if (UPDATE && xpLaeuft()) {
    log(T('Warte, bis X-Plane beendet ist …', 'Waiting for X-Plane to quit …'));
    app.displayNotification(T('Die Installation startet, sobald X-Plane beendet ist.', 'The installation starts as soon as X-Plane has been quit.'),
                            { withTitle: 'P_-Profile ' + version });
    while (xpLaeuft()) delay(15);
    delay(5);
  }

  const sichern = (pfad) => {
    if (!existiert(pfad)) return;
    const rel = pfad.startsWith(HOME + '/') ? pfad.slice(HOME.length + 1) : pfad.replace(/^\//, '');
    sh('mkdir -p ' + q(SICHERUNG + '/' + rel.replace(/\/[^/]+$/, '')) + ' && cp -Rp ' + q(pfad) + ' ' + q(SICHERUNG + '/' + rel));
  };

  // ---------- 6. Flugzeugdateien ----------
  log(T('\nFlugzeugdateien:', '\nAircraft files:'));
  for (const p of gewaehlt) {
    for (const z of zuordnung.filter((z) => z.kurz === p.kurz)) {
      const ordner = acfOrdner(z);
      if (!ordner.length) { log('  – ' + z.acf + T(': Flugzeug nicht gefunden, übersprungen', ': aircraft not found, skipped')); continue; }
      for (const o of ordner) {
        for (const d of [z.konfig, z.kamera]) {
          const ziel = o + '/' + d.replace(/^.*\//, '');
          sichern(ziel);
          sh('cp ' + q(HIER + '/X-Plane/Aircraft/' + d) + ' ' + q(o + '/'));
        }
        log('  ✓ ' + z.acf + ' → ' + o.replace(XP + '/', ''));
      }
    }
  }

  // ---------- Lua ----------
  if (luaGewaehlt.length) {
    if (!existiert(SKRIPTE)) log(T('  FlyWithLua ist nicht installiert – Skripte übersprungen.', '  FlyWithLua is not installed – scripts skipped.'));
    else for (const l of luaGewaehlt) {
      sichern(SKRIPTE + '/' + l.datei);
      sh('cp ' + q(HIER + '/X-Plane/FlyWithLua/Scripts/' + l.datei) + ' ' + q(SKRIPTE + '/'));
      log('  ✓ ' + l.datei);
    }
  }

  // ---------- 7. Stream Deck ----------
  if (!existiert(SD)) abbruch(T('Stream-Deck-Profilordner nicht gefunden. Bitte die Stream-Deck-Software installieren, einmal mit ' +
                                'angeschlossenen Geräten starten und den Installer erneut ausführen.',
                                'Stream Deck profile folder not found. Please install the Stream Deck software, start it once ' +
                                'with the devices connected and run the installer again.'));
  // Geräte-Kennungen aus vorhandenen Profilen (je Modell die erste echte)
  const geraet = {};
  for (const d of ObjC.deepUnwrap($.NSFileManager.defaultManager.contentsOfDirectoryAtPathError(SD, null)) || []) {
    if (!d.endsWith('.sdProfile')) continue;
    try {
      const g = JSON.parse(lesen(SD + '/' + d + '/manifest.json')).Device || {};
      if (g.Model && g.UUID && !g.UUID.includes('P0PROFIL') && !(g.Model in geraet)) geraet[g.Model] = g.UUID;
    } catch (e) {}
  }
  log(geraet[MODELL_XL] ? T('Stream Deck XL erkannt.', 'Stream Deck XL found.') : T('Kein Stream Deck XL – XL-Profile übersprungen.', 'No Stream Deck XL – XL profiles skipped.'));
  log(geraet[MODELL_PLUS] ? T('Stream Deck + erkannt.', 'Stream Deck + found.') : T('Kein Stream Deck + – Plus-Profile übersprungen.', 'No Stream Deck + – Plus profiles skipped.'));

  // Stream Deck beenden und sicher warten, bis der Prozess weg ist – sonst schreibt es beim Beenden seinen alten Stand
  // über die neuen Profile. Im Update-Modus per Signal statt Apple Event (keine Automations-Rückfrage im Hintergrund).
  const SD_PROZESS = 'Elgato Stream Deck.app/Contents/MacOS/Stream Deck';
  if (!TEST) {
    if (UPDATE) sh('pkill -TERM -f ' + q(SD_PROZESS) + ' 2>/dev/null; true');
    else sh("osascript -e 'tell application \"Elgato Stream Deck\" to quit' >/dev/null 2>&1 || true");
    sh('for i in $(seq 1 40); do pgrep -qf ' + q(SD_PROZESS) + ' || break; sleep 0.25; done; ' +
       'pkill -9 -f ' + q(SD_PROZESS) + ' 2>/dev/null; sleep 3; true');
  }
  sichern(SD);
  const xlId = geraet[MODELL_XL] || PLATZ_XL, plusId = geraet[MODELL_PLUS] || PLATZ_PLUS;
  let n = 0;
  for (const p of gewaehlt) {
    for (const [id, modell] of [[p.xl, MODELL_XL], [p.plus, MODELL_PLUS]]) {
      if (!geraet[modell]) continue;
      const name = id.toUpperCase() + '.sdProfile', ziel = SD + '/' + name;
      sh('rm -rf ' + q(ziel) + ' && cp -R ' + q(HIER + '/StreamDeck/Profile/' + name) + ' ' + q(ziel));
      // Platzhalter → eigene Geräte (Kennungen enthalten „/“, daher Textersetzung statt regulärer Ausdrücke)
      for (const mf of sh('find ' + q(ziel) + ' -name manifest.json').split('\r').join('\n').split('\n').filter(Boolean))
        schreiben(mf, lesen(mf).split(PLATZ_XL).join(xlId).split(PLATZ_PLUS).join(plusId));
      n++;
    }
  }
  log(T('  ✓ ', '  ✓ ') + n + T(' Profile installiert.', ' profiles installed.'));

  // Kreis: alle installierten P_-Profile in Paket-Reihenfolge, Zurück = 0,0, Vor = 2,0
  const kreis = profile.filter((p) => installiert(p.xl));
  kreis.forEach((p, i) => {
    const [ordner, pm] = startseite(SD + '/' + p.xl.toUpperCase() + '.sdProfile');
    const a = tasten(pm);
    for (const [pos, nb] of [['0,0', kreis[(i - 1 + kreis.length) % kreis.length]], ['2,0', kreis[(i + 1) % kreis.length]]]) {
      const multi = a[pos] && a[pos].Actions && a[pos].Actions[0] && a[pos].Actions[0].Actions;
      if (!multi || multi.length < 2) continue;
      multi[0].Settings.ProfileUUID = nb.xl;
      multi[1].Settings.ProfileUUID = nb.plus;
    }
    // AeroACARS: anzeigen = Kacheln aus dem Paket übernehmen, ausblenden = Kacheln entfernen
    for (const pos of Object.keys(a)) if (a[pos].Plugin && a[pos].Plugin.UUID === AEROACARS) delete a[pos];
    if (aero) {
      const quelle = HIER + '/StreamDeck/Profile/' + p.xl.toUpperCase() + '.sdProfile';
      if (existiert(quelle)) {
        const qa = tasten(startseite(quelle)[1]);
        for (const pos of Object.keys(qa)) if (qa[pos].Plugin && qa[pos].Plugin.UUID === AEROACARS) a[pos] = qa[pos];
      }
    }
    schreiben(ordner + '/manifest.json', JSON.stringify(pm, null, 1));
  });
  log(T('  ✓ Kreis Vor/Zurück: ', '  ✓ Next/previous circle: ') + kreis.map((p) => p.name).join(' → '));
  log('  ✓ AeroACARS: ' + (aero ? knopfAn : knopfAus));

  // ---------- 8. Installierte Version merken, Update-Helfer ----------
  sh('mkdir -p ' + q(ZUSTAND));
  schreiben(ZUSTAND + '/installiert.txt', version + '\n');
  sh('rm -f ' + q(ZUSTAND + '/abgelehnt.txt'));
  const skript = ZUSTAND + '/update_helfer.sh';
  if (helfer && existiert(HIER + '/StreamDeck/update_helfer.sh'))
    sh('cp ' + q(HIER + '/StreamDeck/update_helfer.sh') + ' ' + q(skript) + ' && chmod 755 ' + q(skript));
  // Den LaunchAgent nur außerhalb des Update-Modus neu laden: im Update-Modus läuft dieser Installer als Kind des
  // Helfers, und „launchctl bootout“ würde ihn mitten in der Arbeit beenden.
  if (!UPDATE) {
    const agenten = TEST ? ZUSTAND : HOME + '/Library/LaunchAgents';
    const plist = agenten + '/' + AGENT + '.plist';
    const uid = sh('id -u');
    if (!TEST) sh('launchctl bootout gui/' + uid + '/' + AGENT + ' 2>/dev/null; true');
    if (helfer) {
      sh('mkdir -p ' + q(agenten));
      schreiben(plist, [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">',
        '<plist version="1.0"><dict>',
        '  <key>Label</key><string>' + AGENT + '</string>',
        '  <key>ProgramArguments</key><array><string>/bin/zsh</string><string>' + xml(skript) + '</string>' +
        '<string>' + xml(XP) + '</string></array>',
        // Auslöser: Änderung im Ordner P_Profile (Updater), dazu alle 30 Minuten und bei der Anmeldung
        '  <key>WatchPaths</key><array><string>' + xml(XP + '/P_Profile') + '</string></array>',
        '  <key>StartInterval</key><integer>1800</integer>',
        '  <key>RunAtLoad</key><true/>',
        '  <key>StandardOutPath</key><string>' + xml(ZUSTAND + '/helfer.log') + '</string>',
        '  <key>StandardErrorPath</key><string>' + xml(ZUSTAND + '/helfer.log') + '</string>',
        '</dict></plist>', ''].join('\n'));
      if (!TEST) sh('launchctl bootstrap gui/' + uid + ' ' + q(plist));
      log(T('  ✓ Automatische Updates eingerichtet.', '  ✓ Automatic updates set up.'));
    } else {
      sh('rm -f ' + q(plist) + ' ' + q(skript));
      log(T('  – Automatische Updates: aus.', '  – Automatic updates: off.'));
    }
  }
  // Update-Modus: nur die letzten drei Sicherungen behalten
  if (UPDATE) sh('cd ' + q(ZUSTAND + '/Sicherungen') + ' 2>/dev/null && ls -1 | sort -r | tail -n +4 | while read -r d; do rm -rf "$d"; done; true');

  if (TEST) return;
  sh('open -a "Elgato Stream Deck" || true');
  log(T('\nFertig. Sicherung: ', '\nDone. Backup: ') + SICHERUNG);
  app.displayDialog((UPDATE ? T('Update auf ' + version + ' installiert.', 'Update to ' + version + ' installed.')
                            : T('Installation abgeschlossen.', 'Installation complete.')) +
                    T('\n\nSicherung der ersetzten Dateien:\n', '\n\nBackup of replaced files:\n') + SICHERUNG,
                    { buttons: ['OK'], defaultButton: 'OK', withTitle: T('P_-Profile', 'P_ Profiles') });
}
