// P_-Profile für X-Plane 12 – Installer macOS (JavaScript for Automation, gestartet von Installieren_macOS.command)
//
// Ablauf:
//   1. Prüfen: X-Plane beendet, X-Plane-Ordner (Standard ~/X-Plane 12, sonst Auswahl).
//   2. Auswahl der Profile (Mehrfachauswahl). Vorbelegt: bereits installierte P_-Profile und Profile, deren Flugzeug
//      im Aircraft-Ordner gefunden wird. Ein erneuter Aufruf installiert weitere Profile nach.
//   3. Auswahl der FlyWithLua-Skripte (optional, vorbelegt: die für die gewählten Flugzeuge nötigen).
//   4. AeroACARS-Kacheln (Startseite XL, Reihe 4, 7 Tasten) anzeigen oder ausblenden.
//   5. Flugzeugdateien (X-KeyPad-Konfiguration, X-Camera-Sichten) neben die passende .acf-Datei kopieren.
//   6. Stream-Deck-Profile kopieren (Geräte-Platzhalter → eigene Geräte), danach Vor/Zurück aller installierten
//      P_-Profile im Kreis neu verknüpfen (nur gewählte + bereits installierte) und die AeroACARS-Wahl auf alle
//      installierten P_-Profile anwenden.
// Jede ersetzte Datei und der Stream-Deck-Profilordner werden vorher nach ~/Documents/P_Profile_Sicherung_<Zeit>/
// gesichert. Paketdateien: StreamDeck/profile.txt (Kreisfolge), X-Plane/zuordnung.txt, X-Plane/FlyWithLua/lua.txt.
// Testmodus (nur Entwicklung): Umgebungsvariablen P_TEST_SD (Profilordner), P_TEST_XP (X-Plane-Ordner),
// P_TEST_WAHL (Kürzel, kommagetrennt), P_TEST_LUA (Dateien, kommagetrennt), P_TEST_AERO (an|aus) ersetzen Ordner und
// Dialoge; die Stream-Deck-Software wird dann weder beendet noch gestartet.

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

const MODELL_XL = '20GAT9902', MODELL_PLUS = '20GBD9901';
const PLATZ_XL = '@(1)[4057/143/P0PROFILXL000]', PLATZ_PLUS = '@(1)[4057/132/P0PROFILPLUS0]';
const AEROACARS = 'eu.german-sky-group.aeroacars';

function abbruch(text) {
  app.displayDialog(text, { buttons: ['OK'], defaultButton: 'OK', withIcon: 'stop',
                            withTitle: T('P_-Profile – Installation', 'P_ Profiles – Installation') });
  throw new Error(text);
}

const umgebung = (n) => { const v = $.NSProcessInfo.processInfo.environment.objectForKey(n); return v.isNil() ? '' : ObjC.unwrap(v); };
const TEST = umgebung('P_TEST_SD') !== '';

function run(argv) {
  const HIER = argv[0];
  const HOME = ObjC.unwrap($.NSHomeDirectory());
  const SD = TEST ? umgebung('P_TEST_SD') : HOME + '/Library/Application Support/com.elgato.StreamDeck/ProfilesV3';
  const stempel = sh('date +%Y-%m-%d_%H%M%S');
  const SICHERUNG = (TEST ? umgebung('P_TEST_XP') + '/..' : HOME + '/Documents') + '/P_Profile_Sicherung_' + stempel;
  const version = existiert(HIER + '/VERSION') ? lesen(HIER + '/VERSION').trim() : '';
  log('================================================================');
  log(' P_-Profile / P_ Profiles – X-Plane 12 – ' + version);
  log('================================================================');

  // ---------- 1. Voraussetzungen ----------
  if (!TEST && sh("pgrep -qf 'X-Plane.app/Contents/MacOS/X-Plane' && echo ja || echo nein") === 'ja')
    abbruch(T('X-Plane läuft noch. Bitte X-Plane beenden und den Installer erneut starten.',
              'X-Plane is still running. Please quit X-Plane and start the installer again.'));
  let XP = TEST ? umgebung('P_TEST_XP') : HOME + '/X-Plane 12';
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
                                    flugzeugDa(p.kurz) ? '' : T('  (Flugzeug nicht gefunden)', '  (aircraft not found)'));
  const liste = profile.map(eintrag);
  const vorbelegt = profile.filter((p) => installiert(p.xl) || flugzeugDa(p.kurz)).map(eintrag);
  const wahl = TEST ? profile.filter((p) => umgebung('P_TEST_WAHL').split(',').includes(p.kurz)).map(eintrag) :
    app.chooseFromList(liste, {
    withTitle: T('P_-Profile – Profile wählen', 'P_ Profiles – choose profiles'),
    withPrompt: T('Welche Profile sollen installiert bzw. aktualisiert werden? (Mehrfachauswahl mit ⌘)\n' +
                  'Bereits installierte, hier abgewählte Profile bleiben unverändert.',
                  'Which profiles should be installed or updated? (multiple selection with ⌘)\n' +
                  'Installed profiles that are not selected here stay unchanged.'),
    defaultItems: vorbelegt, multipleSelectionsAllowed: true, emptySelectionAllowed: true });
  if (wahl === false) abbruch(T('Abgebrochen.', 'Cancelled.'));
  const gewaehlt = profile.filter((p) => wahl.includes(eintrag(p)));

  // ---------- 3. Lua-Skripte ----------
  const luaListe = lua.map((l) => l.datei + ' – ' + l.text);
  const luaVor = lua.filter((l) => gewaehlt.some((p) => l.fuer.includes(p.kurz))).map((l) => l.datei + ' – ' + l.text);
  const luaWahl = TEST ? lua.filter((l) => umgebung('P_TEST_LUA').split(',').includes(l.datei)).map((l) => l.datei + ' – ' + l.text) :
    app.chooseFromList(luaListe, {
    withTitle: T('P_-Profile – FlyWithLua-Skripte', 'P_ Profiles – FlyWithLua scripts'),
    withPrompt: T('Welche FlyWithLua-Skripte sollen installiert werden? (optional; vorbelegt: für die gewählten Flugzeuge nötig)',
                  'Which FlyWithLua scripts should be installed? (optional; preselected: required for the chosen aircraft)'),
    defaultItems: luaVor, multipleSelectionsAllowed: true, emptySelectionAllowed: true });
  const luaGewaehlt = luaWahl === false ? [] : lua.filter((l) => luaWahl.includes(l.datei + ' – ' + l.text));

  // ---------- 4. AeroACARS ----------
  const knopfAn = T('Anzeigen', 'Show'), knopfAus = T('Ausblenden', 'Hide');
  const aero = TEST ? umgebung('P_TEST_AERO') === 'an' : app.displayDialog(T('AeroACARS-Kacheln (Startseite des Stream Deck XL, Reihe 4, 7 Tasten) anzeigen?\n' +
                                   'Sie funktionieren nur mit dem AeroACARS-Plugin für Piloten der German Sky Group. ' +
                                   'Ausgeblendet bleiben die Plätze leer. Die Wahl gilt für alle installierten P_-Profile.',
                                   'Show the AeroACARS tiles (Stream Deck XL start page, row 4, 7 keys)?\n' +
                                   'They only work with the AeroACARS plugin for German Sky Group pilots. When hidden, ' +
                                   'the keys stay empty. The choice applies to all installed P_ profiles.'),
                                 { buttons: [knopfAus, knopfAn], defaultButton: knopfAn,
                                   withTitle: 'AeroACARS' }).buttonReturned === knopfAn;

  if (!TEST) app.displayDialog(
    T('Installieren:\n• ', 'Install:\n• ') + (gewaehlt.map((p) => p.name).join(', ') || T('keine Profile', 'no profiles')) +
    T('\n• Lua: ', '\n• Lua: ') + (luaGewaehlt.map((l) => l.datei).join(', ') || '–') +
    '\n• AeroACARS: ' + (aero ? knopfAn : knopfAus) +
    T('\n\nDie Stream-Deck-Software wird dafür kurz beendet und neu gestartet.',
      '\n\nThe Stream Deck software will be quit briefly and restarted.'),
    { buttons: [T('Abbrechen', 'Cancel'), T('Installieren', 'Install')], defaultButton: T('Installieren', 'Install'),
      cancelButton: T('Abbrechen', 'Cancel'), withTitle: T('P_-Profile – Installation', 'P_ Profiles – Installation') });

  const sichern = (pfad) => {
    if (!existiert(pfad)) return;
    const rel = pfad.startsWith(HOME + '/') ? pfad.slice(HOME.length + 1) : pfad.replace(/^\//, '');
    sh('mkdir -p ' + q(SICHERUNG + '/' + rel.replace(/\/[^/]+$/, '')) + ' && cp -Rp ' + q(pfad) + ' ' + q(SICHERUNG + '/' + rel));
  };

  // ---------- 5. Flugzeugdateien ----------
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
    const skripte = XP + '/Resources/plugins/FlyWithLua/Scripts';
    if (!existiert(skripte)) log(T('  FlyWithLua ist nicht installiert – Skripte übersprungen.', '  FlyWithLua is not installed – scripts skipped.'));
    else for (const l of luaGewaehlt) {
      sichern(skripte + '/' + l.datei);
      sh('cp ' + q(HIER + '/X-Plane/FlyWithLua/Scripts/' + l.datei) + ' ' + q(skripte + '/'));
      log('  ✓ ' + l.datei);
    }
  }

  // ---------- 6. Stream Deck ----------
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

  if (!TEST) sh("osascript -e 'tell application \"Elgato Stream Deck\" to quit' >/dev/null 2>&1 || true");
  if (!TEST) sh("for i in $(seq 1 40); do pgrep -qf 'Elgato Stream Deck.app/Contents/MacOS/Stream Deck' || break; sleep 0.25; done; " +
     "pkill -f 'Elgato Stream Deck.app/Contents/MacOS/Stream Deck' 2>/dev/null; sleep 1; true");
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

  // Startseite eines XL-Profils: [Seitenordner, Manifest]
  function startseite(wurzel) {
    const m = JSON.parse(lesen(wurzel + '/manifest.json'));
    const id = m.Pages.Pages[0].toUpperCase();
    const ordner = wurzel + '/Profiles/' + id;
    return [ordner, JSON.parse(lesen(ordner + '/manifest.json'))];
  }
  const tasten = (pm) => (pm.Controllers.find((c) => c.Type === 'Keypad') || {}).Actions || {};

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

  if (TEST) return;
  sh('open -a "Elgato Stream Deck" || true');
  log(T('\nFertig. Sicherung: ', '\nDone. Backup: ') + SICHERUNG);
  app.displayDialog(T('Installation abgeschlossen.\n\nSicherung der ersetzten Dateien:\n', 'Installation complete.\n\nBackup of replaced files:\n') +
                    SICHERUNG, { buttons: ['OK'], defaultButton: 'OK', withTitle: T('P_-Profile', 'P_ Profiles') });
}
