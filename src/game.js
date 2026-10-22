const AUTHOR = 'lionrealone';
const fs = require('fs');
const path = require('path');
const { execFile, execFileSync } = require('child_process');
const { app } = require('electron');

const APP_ID = '5165210';
const EXE_NAME = 'FindTheNeedle.exe';
const FOLDER_GUESSES = [
  'Find The Needle Demo',
  'Find the Needle Demo',
  'FindTheNeedle Demo',
  'Find The Needle',
];

function readText(file) {
  try {
    return fs.readFileSync(file, 'utf8');
  } catch {
    return '';
  }
}

function normalizeSteamPath(p) {
  if (!p) return '';
  let s = String(p).trim().replace(/^"|"$/g, '');
  s = s.replace(/\\\\/g, '\\').replace(/\//g, '\\');
  try {
    s = path.normalize(s);
  } catch {
    return '';
  }
  if (s.endsWith('\\')) s = s.slice(0, -1);
  return s;
}

function regQuerySteamPaths() {
  const keys = [
    ['HKCU\\Software\\Valve\\Steam', 'SteamPath'],
    ['HKLM\\SOFTWARE\\WOW6432Node\\Valve\\Steam', 'InstallPath'],
    ['HKLM\\SOFTWARE\\Valve\\Steam', 'InstallPath'],
  ];
  const found = [];
  for (const [key, value] of keys) {
    try {
      const out = execFileSync('reg', ['query', key, '/v', value], {
        encoding: 'utf8',
        windowsHide: true,
        timeout: 4000,
      });
      const m = String(out).match(
        new RegExp(`${value}\\s+REG_SZ\\s+(.+)`, 'i'),
      );
      if (m && m[1]) found.push(normalizeSteamPath(m[1]));
    } catch {
      /* key missing */
    }
  }
  return found;
}

function parseLibraryFolders(vdfPath, into) {
  const text = readText(vdfPath);
  if (!text) return;
  for (const m of text.matchAll(/"path"\s+"([^"]+)"/gi)) {
    const p = normalizeSteamPath(m[1]);
    if (p) into.add(p);
  }
}

function steamRoots() {
  const roots = new Set();
  const pf = process.env['ProgramFiles(x86)'] || 'C:\\Program Files (x86)';
  const pf64 = process.env.ProgramFiles || 'C:\\Program Files';
  const local = process.env.LOCALAPPDATA || '';

  for (const p of [
    path.join(pf, 'Steam'),
    path.join(pf64, 'Steam'),
    local ? path.join(local, 'Steam') : '',
    ...regQuerySteamPaths(),
  ]) {
    const n = normalizeSteamPath(p);
    if (n) roots.add(n);
  }

  let changed = true;
  let guard = 0;
  while (changed && guard < 8) {
    changed = false;
    guard += 1;
    for (const root of [...roots]) {
      const before = roots.size;
      parseLibraryFolders(
        path.join(root, 'steamapps', 'libraryfolders.vdf'),
        roots,
      );
      parseLibraryFolders(
        path.join(root, 'config', 'libraryfolders.vdf'),
        roots,
      );
      if (roots.size !== before) changed = true;
    }
  }

  return [...roots].filter((r) => {
    try {
      return fs.existsSync(r);
    } catch {
      return false;
    }
  });
}

function looksLikeGameDir(dir) {
  if (!dir) return false;
  try {
    return fs.existsSync(path.join(dir, EXE_NAME));
  } catch {
    return false;
  }
}

function saveGameDirMarker(dir) {
  try {
    const marker = path.join(app.getPath('userData'), 'game-dir.txt');
    fs.mkdirSync(path.dirname(marker), { recursive: true });
    fs.writeFileSync(marker, dir, 'utf8');
  } catch {
    /* ignore */
  }
}

function findGameInstall() {
  const marker = path.join(app.getPath('userData'), 'game-dir.txt');
  if (fs.existsSync(marker)) {
    const dir = normalizeSteamPath(readText(marker).trim());
    if (looksLikeGameDir(dir)) {
      return { gameDir: dir, steamPath: guessSteamNear(dir) };
    }
  }

  const roots = steamRoots();

  for (const root of roots) {
    const manifest = path.join(
      root,
      'steamapps',
      `appmanifest_${APP_ID}.acf`,
    );
    if (!fs.existsSync(manifest)) continue;
    const body = readText(manifest);
    const m = body.match(/"installdir"\s+"([^"]+)"/i);
    if (!m) continue;
    const gameDir = path.join(root, 'steamapps', 'common', m[1]);
    if (looksLikeGameDir(gameDir)) {
      return { gameDir, steamPath: root };
    }
  }

  for (const root of roots) {
    for (const name of FOLDER_GUESSES) {
      const guess = path.join(root, 'steamapps', 'common', name);
      if (looksLikeGameDir(guess)) {
        return { gameDir: guess, steamPath: root };
      }
    }
  }

  // Last resort: scan steamapps/common for FindTheNeedle.exe (one level).
  for (const root of roots) {
    const common = path.join(root, 'steamapps', 'common');
    let entries = [];
    try {
      entries = fs.readdirSync(common, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const entry of entries) {
      if (!entry.isDirectory()) continue;
      const gameDir = path.join(common, entry.name);
      if (looksLikeGameDir(gameDir)) {
        const lower = entry.name.toLowerCase();
        if (lower.includes('needle') || lower.includes('find')) {
          return { gameDir, steamPath: root };
        }
      }
    }
  }

  return null;
}

function guessSteamNear(gameDir) {
  let cur = path.resolve(gameDir);
  for (let i = 0; i < 8; i++) {
    const steamExe = path.join(cur, 'steam.exe');
    if (fs.existsSync(steamExe)) return cur;
    const parent = path.dirname(cur);
    if (parent === cur) break;
    cur = parent;
  }
  const roots = steamRoots();
  for (const root of roots) {
    if (fs.existsSync(path.join(root, 'steam.exe'))) return root;
  }
  const pf = process.env['ProgramFiles(x86)'] || 'C:\\Program Files (x86)';
  return path.join(pf, 'Steam');
}

function isGameRunning() {
  return new Promise((resolve) => {
    execFile(
      'tasklist',
      ['/FO', 'CSV', '/NH'],
      { windowsHide: true },
      (err, stdout) => {
        if (err) {
          resolve(false);
          return;
        }
        const lines = String(stdout).split(/\r?\n/);
        for (const line of lines) {
          const name = (line.match(/^"([^"]+)"/) || [])[1] || '';
          const n = name.toLowerCase();
          if (n === 'findtheneedle.exe') {
            resolve(true);
            return;
          }
        }
        resolve(false);
      },
    );
  });
}

function waitForGameExit() {
  return new Promise((resolve) => {
    let seen = false;
    const started = Date.now();
    const tick = async () => {
      const running = await isGameRunning();
      if (running) seen = true;
      if (seen && !running) {
        resolve('exited');
        return;
      }
      if (!seen && Date.now() - started > 180000) {
        resolve('timeout');
        return;
      }
      setTimeout(tick, 2000);
    };
    setTimeout(tick, 3000);
  });
}

module.exports = {
  AUTHOR,
  APP_ID,
  EXE_NAME,
  findGameInstall,
  looksLikeGameDir,
  saveGameDirMarker,
  isGameRunning,
  waitForGameExit,
};
