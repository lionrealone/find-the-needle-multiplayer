const AUTHOR = 'lionrealone';
const fs = require('fs');
const path = require('path');

// Steam release "Find The Needle" — the launcher is release-only now.
const APP_ID = '5160800';
const EXE_NAME = 'FindTheNeedle.exe';
const FOLDER_GUESSES = ['Needle in a Haystack', 'Find The Needle'];

function steamLaunchArgs() {
  return ['-applaunch', APP_ID];
}

function steamRunUrl() {
  return `steam://rungameid/${APP_ID}`;
}

function isDemoFolderName(name) {
  return /demo/i.test(String(name || ''));
}

function looksLikeGameDir(dir) {
  if (!dir) return false;
  try {
    return fs.existsSync(path.join(dir, EXE_NAME));
  } catch {
    return false;
  }
}

function isReleaseGameDir(dir) {
  return looksLikeGameDir(dir) && !isDemoFolderName(path.basename(dir));
}

function hasUiFiles(root) {
  return (
    fs.existsSync(path.join(root, 'renderer', 'index.html')) &&
    fs.existsSync(path.join(root, 'preload.js'))
  );
}

// Packaged: appPath is the asar root (electron-builder maps src/ -> app root).
// Dev (electron .): appPath is the repo root, the UI lives in src/.
function pickAppRoot(appPath, scriptDir) {
  if (appPath && hasUiFiles(appPath)) return appPath;
  return scriptDir;
}

module.exports = {
  AUTHOR,
  APP_ID,
  EXE_NAME,
  FOLDER_GUESSES,
  steamLaunchArgs,
  steamRunUrl,
  isDemoFolderName,
  looksLikeGameDir,
  isReleaseGameDir,
  pickAppRoot,
};
