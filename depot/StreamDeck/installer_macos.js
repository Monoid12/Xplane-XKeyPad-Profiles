// P_-Profile für X-Plane 12 – Installer macOS (JavaScript for Automation, gestartet von Installieren_macOS.command
// oder im Update-Modus vom Update-Helfer)
//
// Ablauf:
//   1. Prüfen: X-Plane beendet (im Update-Modus: warten, bis X-Plane beendet ist), X-Plane-Ordner (der Ordner über
//      P_Profile, sonst Standard ~/X-Plane 12, sonst Auswahl).
//   2.–5. Ein Fenster (Cocoa, Rückfallebene: Einzeldialoge) mit allen Wahlmöglichkeiten:
//   2. Profile (Kästchen mit Status installiert / Flugzeug vorhanden / nicht gefunden). Vorbelegt: bereits installierte P_-Profile und Profile, deren Flugzeug
//      im Aircraft-Ordner gefunden wird (Update-Modus: nur die installierten). Ein erneuter Aufruf installiert weitere
//      Profile nach.
//   3. FlyWithLua-Skripte (optional, vorbelegt: die für die gewählten Flugzeuge nötigen; Update-Modus:
//      zusätzlich die bereits installierten).
//   4. AeroACARS-Kacheln (Startseite XL, Reihe 4, 7 Tasten) anzeigen oder ausblenden (vorbelegt: bisherige Wahl).
//   5. Automatische Updates: Update-Helfer einrichten oder entfernen (vorbelegt: ja).
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
// P_TEST_LUA (Dateien, kommagetrennt), P_TEST_AERO (an|aus), P_TEST_HELFER (an|aus) ersetzen Ordner und Fenster;
// P_TEST_BILD (Pfad .png, dazu P_TEST_HELL an|aus) speichert nur das Fenster als Bild;
// die Stream-Deck-Software wird dann weder beendet noch gestartet, launchctl wird nicht aufgerufen.

ObjC.import('Cocoa');
const app = Application.currentApplication();
app.includeStandardAdditions = true;

const SPRACHE = (() => { const v = $.NSProcessInfo.processInfo.environment.objectForKey('P_TEST_SPRACHE'); return v.isNil() ? '' : ObjC.unwrap(v); })();
const DE = SPRACHE ? SPRACHE === 'de' :          // P_TEST_SPRACHE (de|en): nur Entwicklung, z. B. Handbuch-Bilder
  (() => { try { return app.doShellScript('defaults read -g AppleLocale').toLowerCase().startsWith('de'); }
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

// ---------- Auswahlfenster (Cocoa) ----------
// Ein Fenster statt mehrerer Dialoge: Profile (Kästchen + Status), Zusätze (Lua-Skripte, AeroACARS, automatische
// Updates), Hinweise, „Später/Abbrechen“ und „Installieren“. Hakt man ein neues Profil an, werden die dafür nötigen
// Lua-Skripte mit angehakt.
let FENSTER = null;                                 // Zustand für die Knopf-Aktionen

function fensterKlasse() {
  if (!$.NSClassFromString('PPFensterZiel').isNil()) return;
  ObjC.registerSubclass({
    name: 'PPFensterZiel', superclass: 'NSObject',
    methods: {
      'installieren:': { types: ['void', ['id']], implementation: function (s) { $.NSApp.stopModalWithCode(1000); } },
      'abbrechen:': { types: ['void', ['id']], implementation: function (s) { $.NSApp.stopModalWithCode(1001); } },
      'alleDa:': { types: ['void', ['id']], implementation: function (s) {
        FENSTER.profil.forEach((k, i) => { if (FENSTER.zeilen[i].art !== 'fehlt') k.state = 1; });
        FENSTER.luaNachziehen(); } },
      'nurInstalliert:': { types: ['void', ['id']], implementation: function (s) {
        FENSTER.profil.forEach((k, i) => { k.state = FENSTER.zeilen[i].art === 'installiert' ? 1 : 0; }); } },
      'profilGeklickt:': { types: ['void', ['id']], implementation: function (s) { FENSTER.luaNachziehen(); } },
    },
  });
}

// o: { titel, untertitel, zeilen:[{name, status, art: installiert|da|fehlt, an}], lua:[{text, an, fuer:[Index…]}],
//      aero, helfer, hinweis, abbrechen, ok, bild, hell }
// → { profil:[bool], lua:[bool], aero, helfer } oder null („Später“/„Abbrechen“)
function auswahlFenster(o) {
  fensterKlasse();
  const W = 600, R = 20, ZH = 22, LISTE = 290;
  const zusatzH = (o.lua.length + 2) * ZH;
  const H = R + 46 + 12 + 18 + LISTE + 8 + 26 + 14 + 18 + zusatzH + 10 + (o.hinweis ? 22 : 0) + 22 + 52;
  $.NSApplication.sharedApplication;
  const win = $.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer($.NSMakeRect(0, 0, W, H), 1, 2, false);
  win.title = T('P_-Profile', 'P_ Profiles');
  const cv = win.contentView;
  const ziel = $.PPFensterZiel.alloc.init;
  let y = H - R;                                    // obere Kante der nächsten Zeile (AppKit zählt von unten)
  const farbe = { installiert: $.NSColor.systemGreenColor, da: $.NSColor.systemBlueColor, fehlt: $.NSColor.tertiaryLabelColor };
  function text(s, x, oben, w, h, groesse, fett, f, rechts) {
    const t = $.NSTextField.labelWithString(s);
    t.font = fett ? $.NSFont.boldSystemFontOfSize(groesse) : $.NSFont.systemFontOfSize(groesse);
    if (f) t.textColor = f;
    if (rechts) t.alignment = $.NSTextAlignmentRight;
    t.frame = $.NSMakeRect(x, oben - h, w, h);
    return t;
  }
  function kasten(titel, an, x, oben, w, aktion) {
    const b = $.NSButton.alloc.initWithFrame($.NSMakeRect(x, oben - 20, w, 20));
    b.setButtonType(3);                             // NSButtonTypeSwitch: Kästchen
    b.title = titel; b.state = an ? 1 : 0;
    if (aktion) { b.target = ziel; b.action = aktion; }
    return b;
  }
  function knopf(titel, x, unten, w, aktion, taste) {
    const b = $.NSButton.alloc.initWithFrame($.NSMakeRect(x, unten, w, 32));
    b.bezelStyle = 1; b.title = titel; b.target = ziel; b.action = aktion;
    if (taste) b.keyEquivalent = taste;
    cv.addSubview(b); return b;
  }

  // Kopf: Symbol, Titel, Untertitel
  const sym = $.NSImage.imageWithSystemSymbolNameAccessibilityDescription('arrow.triangle.2.circlepath.circle.fill', 'Update');
  if (!sym.isNil()) {
    const iv = $.NSImageView.imageViewWithImage(sym);
    iv.frame = $.NSMakeRect(R, y - 40, 40, 40);
    iv.symbolConfiguration = $.NSImageSymbolConfiguration.configurationWithPointSizeWeight(30, 0);
    iv.contentTintColor = $.NSColor.controlAccentColor;
    cv.addSubview(iv);
  }
  cv.addSubview(text(o.titel, R + 50, y - 2, W - 2 * R - 50, 20, 15, true));
  cv.addSubview(text(o.untertitel, R + 50, y - 22, W - 2 * R - 50, 18, 12, false, $.NSColor.secondaryLabelColor));
  y -= 46 + 12;

  // Profile: Liste mit Kästchen und Status
  cv.addSubview(text(T('Profile', 'Profiles'), R, y, 200, 16, 11, true, $.NSColor.secondaryLabelColor)); y -= 18;
  const sv = $.NSScrollView.alloc.initWithFrame($.NSMakeRect(R, y - LISTE, W - 2 * R, LISTE));
  sv.hasVerticalScroller = true; sv.borderType = 2; sv.autohidesScrollers = true;
  const dw = W - 2 * R - 18, dh = Math.max(LISTE - 4, o.zeilen.length * ZH + 6);
  const doc = $.NSView.alloc.initWithFrame($.NSMakeRect(0, 0, dw, dh));
  const profil = o.zeilen.map((z, i) => {
    const oben = dh - 3 - i * ZH;
    const k = kasten(z.name, z.an, 8, oben, dw - 190, 'profilGeklickt:');
    doc.addSubview(k);
    doc.addSubview(text(z.status, dw - 180, oben - 2, 170, 16, 11, false, farbe[z.art], true));
    return k;
  });
  sv.documentView = doc;
  doc.scrollPoint($.NSMakePoint(0, dh));
  cv.addSubview(sv);
  y -= LISTE + 8;
  knopf(T('Alle vorhandenen', 'All found'), R - 6, y - 26, 150, 'alleDa:');
  knopf(T('Nur installierte', 'Installed only'), R + 150, y - 26, 140, 'nurInstalliert:');
  y -= 26 + 14;

  // Zusätze
  cv.addSubview(text(T('Zusätze', 'Extras'), R, y, 200, 16, 11, true, $.NSColor.secondaryLabelColor)); y -= 18;
  const lua = o.lua.map((l, i) => { const k = kasten(l.text, l.an, R, y - i * ZH, W - 2 * R); cv.addSubview(k); return k; });
  y -= o.lua.length * ZH;
  const aero = kasten(T('AeroACARS-Kacheln anzeigen (Startseite XL, Reihe 4)', 'Show AeroACARS tiles (XL start page, row 4)'),
                      o.aero, R, y, W - 2 * R);
  cv.addSubview(aero); y -= ZH;
  const helfer = kasten(T('Automatische Updates (Fenster öffnet sich nach jedem Update von selbst)',
                          'Automatic updates (this window opens by itself after every update)'), o.helfer, R, y, W - 2 * R);
  cv.addSubview(helfer); y -= ZH + 10;

  if (o.hinweis) { cv.addSubview(text(o.hinweis, R, y, W - 2 * R, 18, 12, false, $.NSColor.systemOrangeColor)); y -= 22; }
  cv.addSubview(text(T('Stream Deck wird dafür kurz neu gestartet; ersetzte Dateien werden vorher gesichert.',
                       'Stream Deck is restarted briefly; replaced files are backed up first.'),
                     R, y, W - 2 * R, 18, 11, false, $.NSColor.secondaryLabelColor));

  // Knöpfe (Eingabe = Installieren, Esc = Später/Abbrechen)
  const ok = knopf(o.ok, W - R - 130 + 6, R - 6, 130, 'installieren:', '\r');
  knopf(o.abbrechen, W - R - 260 + 6, R - 6, 124, 'abbrechen:', '\u001b');
  win.defaultButtonCell = ok.cell;

  FENSTER = { profil, zeilen: o.zeilen,
    luaNachziehen: () => o.lua.forEach((l, j) => {
      if (l.fuer.some((i) => Number(profil[i].state) === 1 && o.zeilen[i].art !== 'installiert')) lua[j].state = 1; }) };

  if (o.bild) {                                     // nur Entwicklung: Fenster als Bild speichern statt anzeigen
    if (o.hell !== undefined) win.appearance = $.NSAppearance.appearanceNamed(o.hell ? 'NSAppearanceNameAqua' : 'NSAppearanceNameDarkAqua');
    const fv = cv.superview;
    fv.layoutSubtreeIfNeeded; win.displayIfNeeded;
    const rep = fv.bitmapImageRepForCachingDisplayInRect(fv.bounds);
    fv.cacheDisplayInRectToBitmapImageRep(fv.bounds, rep);
    rep.representationUsingTypeProperties(4, $()).writeToFileAtomically(o.bild, true);
    return null;
  }
  $.NSApp.setActivationPolicy(1);                   // Zubehör-App: Fenster ohne Dock-Symbol, aber im Vordergrund
  $.NSApp.activateIgnoringOtherApps(true);
  win.center; win.makeKeyAndOrderFront($());
  const code = $.NSApp.runModalForWindow(win);
  win.orderOut($());
  if (Number(code) !== 1000) return null;          // die Brücke liefert den Rückgabewert als Text („1000“)
  return { profil: profil.map((k) => Number(k.state) === 1), lua: lua.map((k) => Number(k.state) === 1),
           aero: Number(aero.state) === 1, helfer: Number(helfer.state) === 1 };
}

// Rückfallebene, falls das Fenster nicht aufgeht: die bisherigen Einzeldialoge (gleiches Ergebnis-Format)
function auswahlDialoge(o) {
  const nr = (z, i) => z.name + '  (' + z.status + ')';
  const wahl = app.chooseFromList(o.zeilen.map(nr), { withTitle: o.titel, withPrompt: o.untertitel,
    okButtonName: T('Weiter', 'Next'), cancelButtonName: o.abbrechen,
    defaultItems: o.zeilen.filter((z) => z.an).map(nr), multipleSelectionsAllowed: true, emptySelectionAllowed: true });
  if (wahl === false) return null;
  const profil = o.zeilen.map((z) => wahl.includes(nr(z)));
  const lw = app.chooseFromList(o.lua.map((l) => l.text), { withTitle: T('FlyWithLua-Skripte', 'FlyWithLua scripts'),
    withPrompt: T('Welche FlyWithLua-Skripte sollen installiert werden? (optional)', 'Which FlyWithLua scripts should be installed? (optional)'),
    defaultItems: o.lua.filter((l, j) => l.an || l.fuer.some((i) => profil[i] && o.zeilen[i].art !== 'installiert')).map((l) => l.text),
    multipleSelectionsAllowed: true, emptySelectionAllowed: true });
  const ja = T('Ja', 'Yes'), nein = T('Nein', 'No');
  const frage = (t, vor) => app.displayDialog(t, { buttons: [nein, ja], defaultButton: vor ? ja : nein, withTitle: o.titel }).buttonReturned === ja;
  const aero = frage(T('AeroACARS-Kacheln (Startseite XL, Reihe 4) anzeigen?', 'Show the AeroACARS tiles (XL start page, row 4)?'), o.aero);
  const helfer = frage(T('Automatische Updates einrichten? (Fenster öffnet sich nach jedem Update von selbst)',
                         'Set up automatic updates? (the window opens by itself after every update)'), o.helfer);
  try {
    app.displayDialog(T('Jetzt installieren? Stream Deck wird dafür kurz neu gestartet.', 'Install now? Stream Deck is restarted briefly.') +
                      (o.hinweis ? '\n\n' + o.hinweis : ''),
                      { buttons: [o.abbrechen, o.ok], defaultButton: o.ok, cancelButton: o.abbrechen, withTitle: o.titel });
  } catch (e) { return null; }
  return { profil, lua: o.lua.map((l) => lw !== false && lw.includes(l.text)), aero, helfer };
}

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

  // ---------- 2.–5. Auswahl im Fenster: Profile, Lua-Skripte, AeroACARS, automatische Updates ----------
  const statusText = { installiert: T('installiert', 'installed'), da: T('Flugzeug vorhanden', 'aircraft found'),
                       fehlt: T('Flugzeug nicht gefunden', 'aircraft not found') };
  const zeilenP = profile.map((p) => {
    const art = installiert(p.xl) ? 'installiert' : flugzeugDa(p.kurz) ? 'da' : 'fehlt';
    // vorbelegt: installierte; außerhalb des Update-Modus auch alle, deren Flugzeug gefunden wird
    return { name: p.name, art, status: statusText[art], an: art === 'installiert' || (!UPDATE && art === 'da') };
  });
  const luaDa = (l) => existiert(SKRIPTE + '/' + l.datei);
  const zeilenL = lua.map((l) => {
    const fuer = profile.map((p, i) => (l.fuer.includes(p.kurz) ? i : -1)).filter((i) => i >= 0);
    // vorbelegt: für vorbelegte Profile nötig (Update-Modus: für neu gewählte) und – im Update-Modus – bereits installiert
    const an = (UPDATE && luaDa(l)) || fuer.some((i) => zeilenP[i].an && !(UPDATE && zeilenP[i].art === 'installiert'));
    return { text: l.datei + ' – ' + l.text, an, fuer };
  });
  const nInst = zeilenP.filter((z) => z.art === 'installiert').length, nNeu = zeilenP.filter((z) => z.art === 'da').length;
  const aeroVor = nInst ? profile.some((p) => installiert(p.xl) && hatAero(p.xl)) : true;
  const altVersion = existiert(ZUSTAND + '/installiert.txt') ? lesen(ZUSTAND + '/installiert.txt').trim() : '';
  const fenster = {
    titel: UPDATE ? T('Version ' + version + ' ist bereit', 'Version ' + version + ' is ready')
                  : T('P_-Profile ' + version + ' installieren', 'Install P_ Profiles ' + version),
    untertitel: UPDATE
      ? T('Installiert: ' + (altVersion || '–') + ' · ' + nInst + ' von ' + profile.length + ' Profilen auf diesem Mac',
          'Installed: ' + (altVersion || '–') + ' · ' + nInst + ' of ' + profile.length + ' profiles on this Mac')
      : T(nInst + ' Profile installiert · ' + nNeu + ' weitere Flugzeuge in X-Plane gefunden',
          nInst + ' profiles installed · ' + nNeu + ' more aircraft found in X-Plane'),
    zeilen: zeilenP, lua: zeilenL, aero: aeroVor, helfer: true,
    hinweis: UPDATE && xpLaeuft() ? T('X-Plane läuft gerade – die Installation startet von selbst, sobald X-Plane beendet ist.',
                                      'X-Plane is running – the installation starts by itself as soon as X-Plane has been quit.') : '',
    abbrechen: UPDATE ? T('Später', 'Later') : T('Abbrechen', 'Cancel'), ok: T('Installieren', 'Install'),
  };
  let auswahl;
  if (TEST && umgebung('P_TEST_BILD')) {             // nur Entwicklung: Fenster als Bild speichern
    auswahlFenster(Object.assign(fenster, { bild: umgebung('P_TEST_BILD'), hell: umgebung('P_TEST_HELL') === 'an' }));
    return;
  }
  if (TEST) {
    const w = umgebung('P_TEST_WAHL').split(','), lw = umgebung('P_TEST_LUA').split(',');
    auswahl = { profil: profile.map((p) => w.includes(p.kurz)), lua: lua.map((l) => lw.includes(l.datei)),
                aero: umgebung('P_TEST_AERO') === 'an', helfer: umgebung('P_TEST_HELFER') === 'an' || (UPDATE && umgebung('P_TEST_HELFER') === '') };
  } else {
    try { auswahl = auswahlFenster(fenster); }
    catch (e) { log(T('Fenster nicht verfügbar (', 'Window not available (') + e + T(') – Einzeldialoge.', ') – single dialogs.'));
                auswahl = auswahlDialoge(fenster); }
  }
  if (!auswahl) { if (UPDATE) spaeter(); abbruch(T('Abgebrochen.', 'Cancelled.')); }
  const gewaehlt = profile.filter((p, i) => auswahl.profil[i]);
  const luaGewaehlt = lua.filter((l, j) => auswahl.lua[j]);
  const aero = auswahl.aero, helfer = auswahl.helfer;
  const knopfAn = T('Anzeigen', 'Show'), knopfAus = T('Ausblenden', 'Hide');

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
  const agenten = TEST ? ZUSTAND : HOME + '/Library/LaunchAgents';
  const plist = agenten + '/' + AGENT + '.plist';
  const uid = sh('id -u');
  if (!UPDATE) {
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

  // Update-Modus, automatische Updates abgewählt: Helfer-Dateien entfernen; den LaunchAgent erst ganz am Ende abmelden
  const helferAbmelden = UPDATE && !helfer;
  if (helferAbmelden) { sh('rm -f ' + q(plist) + ' ' + q(skript)); log(T('  – Automatische Updates: aus.', '  – Automatic updates: off.')); }

  if (TEST) return;
  sh('open -a "Elgato Stream Deck" || true');
  log(T('\nFertig. Sicherung: ', '\nDone. Backup: ') + SICHERUNG);
  app.displayDialog((UPDATE ? T('Update auf ' + version + ' installiert.', 'Update to ' + version + ' installed.')
                            : T('Installation abgeschlossen.', 'Installation complete.')) +
                    T('\n\nSicherung der ersetzten Dateien:\n', '\n\nBackup of replaced files:\n') + SICHERUNG,
                    { buttons: ['OK'], defaultButton: 'OK', withTitle: T('P_-Profile', 'P_ Profiles') });
  // als letzte Aktion: beendet diesen Installer mit, weil er als Kind des Helfers läuft – alles ist dann erledigt
  if (helferAbmelden) sh('launchctl bootout gui/' + uid + '/' + AGENT + ' 2>/dev/null; true');
}
