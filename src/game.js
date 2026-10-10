const AUTHOR = 'lionderwahre';
const fs = require('fs');
const path = require('path');
const { execFile } = require('child_process');
const { app } = require('electron');

const APP_ID = '5165210';
const EXE_NAME = 'FindTheNeedle.exe';

function readText(file) {
  try {
    return fs.readFileSync(file, 'utf8');
  } catch {
    return '';
  }
}

function steamRoots() {
  const roots = new Set();
  const pf = process.env['ProgramFiles(x86)'] || 'C:\\Program Files (x86)';
  const pf64 = process.env.ProgramFiles || 'C:\\Program Files';
  roots.add(path.join(pf, 'Steam'));
  roots.add(path.join(pf64, 'Steam'));

  const mainVdf = path.join(pf, 'Steam', 'steamapps', 'libraryfolders.vdf');
  const text = readText(mainVdf);
  for (const m of text.matchAll(/"path"\s+"([^"]+)"/g)) {
    roots.add(m[1].replace(/\\\\/g, '\\'));
  }
  return [...roots].filter((r) => fs.existsSync(r));
}

function findGameInstall() {
  const marker = path.join(app.getPath('userData'), 'game-dir.txt');
  if (fs.existsSync(marker)) {
    const dir = readText(marker).trim();
    if (dir && fs.existsSync(path.join(dir, EXE_NAME))) {
      return { gameDir: dir, steamPath: guessSteamNear(dir) };
    }
  }

  for (const root of steamRoots()) {
    const manifest = path.join(
      root,
      'steamapps',
      `appmanifest_${APP_ID}.acf`,
    );
    if (!fs.existsSync(manifest)) continue;
    const body = readText(manifest);
    const m = body.match(/"installdir"\s+"([^"]+)"/);
    if (!m) continue;
    const gameDir = path.join(root, 'steamapps', 'common', m[1]);
    if (fs.existsSync(path.join(gameDir, EXE_NAME))) {
      return { gameDir, steamPath: root };
    }
  }

  for (const root of steamRoots()) {
    const guess = path.join(root, 'steamapps', 'common', 'Find The Needle Demo');
    if (fs.existsSync(path.join(guess, EXE_NAME))) {
      return { gameDir: guess, steamPath: root };
    }
  }

  return null;
}

function guessSteamNear(gameDir) {
  let cur = path.resolve(gameDir);
  for (let i = 0; i < 6; i++) {
    const steamExe = path.join(cur, 'steam.exe');
    if (fs.existsSync(steamExe)) return cur;
    const parent = path.dirname(cur);
    if (parent === cur) break;
    cur = parent;
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
  APP_ID,
  EXE_NAME,
  findGameInstall,
  isGameRunning,
  waitForGameExit,
};
