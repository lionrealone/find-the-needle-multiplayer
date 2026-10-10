const AUTHOR = 'lionderwahre';

const FALLBACK = 'en';

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
      'Find The Needle Demo not found. Install the demo from Steam and open Steam once.',
    game_already_running: 'The game is already running. Please close it first.',
    game_not_found: 'Game not found.',
    pick_folder_title: 'Select FindTheNeedle.exe folder',
    no_exe_in_folder: 'This folder has no FindTheNeedle.exe.',
    no_write_access:
      'No write access to the game folder. Run the launcher once as administrator.',
    disable_failed: 'Could not disable the mod (no write permission).',
  },
};

function lang() {
  return FALLBACK;
}

function t(key) {
  const table = STRINGS[FALLBACK];
  if (table[key] != null) return table[key];
  return key;
}

module.exports = { AUTHOR, FALLBACK, STRINGS, lang, t };
