const AUTHOR = 'lionrealone';

const STRINGS = {
  en: {
    lede: 'Start the game to play with your friends.',
    start: 'Start game!',
    starting: 'Starting…',
    game_starting: 'Game is starting…',
    game_running: 'Game is running.',
    start_failed: 'Start failed.',
    please_wait: 'Please wait…',
    demo_missing:
      'Demo not found. Install Find The Needle Demo on Steam, or select FindTheNeedle.exe.',
    pick_folder: 'Select FindTheNeedle.exe…',
    open_steam_demo: 'Open Steam demo page',
    game_already_running: 'The game is already running. Please close it first.',
    game_not_found: 'Game not found.',
    pick_folder_title: 'Select FindTheNeedle.exe',
    no_exe_in_folder: 'Please select FindTheNeedle.exe from the Steam demo folder.',
    folder_saved: 'Game folder saved.',
    no_write_access:
      'No write access to the game folder. Run the launcher once as administrator.',
    disable_failed: 'Could not disable the mod (no write permission).',
  },
  de: {
    lede: 'Starte das Spiel, um mit Freunden zu spielen.',
    start: 'Spiel starten!',
    starting: 'Startet…',
    game_starting: 'Spiel startet…',
    game_running: 'Spiel läuft.',
    start_failed: 'Start fehlgeschlagen.',
    please_wait: 'Bitte warten…',
    demo_missing:
      'Demo nicht gefunden. Installiere Find The Needle Demo über Steam oder wähle FindTheNeedle.exe.',
    pick_folder: 'FindTheNeedle.exe wählen…',
    open_steam_demo: 'Steam-Demo öffnen',
    game_already_running: 'Das Spiel läuft bereits. Bitte zuerst schließen.',
    game_not_found: 'Spiel nicht gefunden.',
    pick_folder_title: 'FindTheNeedle.exe auswählen',
    no_exe_in_folder:
      'Bitte FindTheNeedle.exe aus dem Steam-Demo-Ordner auswählen.',
    folder_saved: 'Spielordner gespeichert.',
    no_write_access:
      'Kein Schreibzugriff auf den Spielordner. Launcher einmal als Administrator starten.',
    disable_failed: 'Mod konnte nicht deaktiviert werden (keine Schreibrechte).',
  },
};

function lang() {
  const raw = String(
    process.env.LANG ||
      process.env.LANGUAGE ||
      (typeof Intl !== 'undefined'
        ? Intl.DateTimeFormat().resolvedOptions().locale
        : '') ||
      '',
  ).toLowerCase();
  if (raw.startsWith('de')) return 'de';
  return 'en';
}

function t(key) {
  const code = lang();
  const table = STRINGS[code] || STRINGS.en;
  if (table[key] != null) return table[key];
  if (STRINGS.en[key] != null) return STRINGS.en[key];
  return key;
}

module.exports = { AUTHOR, STRINGS, lang, t };
