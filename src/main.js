const AUTHOR = 'lionderwahre';
const {
  app,
  BrowserWindow,
  ipcMain,
  shell,
  dialog,
} = require('electron');
const path = require('path');
const fs = require('fs');
const { pathToFileURL } = require('url');
const { spawn } = require('child_process');
const { findGameInstall, isGameRunning } = require('./game');
const {
  enableMod,
  disableMod,
  isModEnabled,
  getModSourceDir,
} = require('./mod');
const { runCleanupWatch } = require('./cleanup-watch');
const { t } = require('./i18n');

const cleanupIdx = process.argv.indexOf('--needle-cleanup');
if (cleanupIdx !== -1) {
  const gameDir = process.argv[cleanupIdx + 1] || '';
  app.whenReady().then(() => {
    runCleanupWatch(gameDir).finally(() => app.exit(0));
  });
} else {
  bootLauncher();
}

function bootLauncher() {
  const gotLock = app.requestSingleInstanceLock();
  if (!gotLock) {
    app.quit();
    return;
  }

  let win = null;
  let busy = false;
  let launching = false;
  let booting = true;

  function iconPath() {
    const packed = path.join(process.resourcesPath, 'icon.png');
    if (fs.existsSync(packed)) return packed;
    const dev = path.join(__dirname, '..', 'build', 'icon.png');
    if (fs.existsSync(dev)) return dev;
    const ico = path.join(__dirname, '..', 'build', 'icon.ico');
    if (fs.existsSync(ico)) return ico;
    return undefined;
  }

  function hardenWindow(w) {
    w.setMenuBarVisibility(false);
    w.removeMenu();
    w.webContents.on('before-input-event', (event, input) => {
      const key = String(input.key || '').toLowerCase();
      if (input.control && input.shift && (key === 'i' || key === 'j' || key === 'c')) {
        event.preventDefault();
      }
      if (input.control && key === 'u') event.preventDefault();
      if (key === 'f12') event.preventDefault();
    });
    w.webContents.on('devtools-opened', () => {
      try {
        w.webContents.closeDevTools();
      } catch (_) {}
    });
    w.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  }

  function appRoot() {
    try {
      return app.getAppPath();
    } catch (_) {
      return __dirname;
    }
  }

  function createWindow() {
    const root = appRoot();
    let preload = path.join(root, 'preload.js');
    let page = path.join(root, 'renderer', 'index.html');
    const unpackedPreload = preload.replace('app.asar', 'app.asar.unpacked');
    const unpackedPage = page.replace('app.asar', 'app.asar.unpacked');
    if (fs.existsSync(unpackedPreload)) preload = unpackedPreload;
    if (fs.existsSync(unpackedPage)) page = unpackedPage;

    const opts = {
      width: 720,
      height: 480,
      minWidth: 560,
      minHeight: 380,
      backgroundColor: '#08070e',
      title: 'Find The Needle',
      autoHideMenuBar: true,
      show: true,
      webPreferences: {
        preload,
        contextIsolation: true,
        nodeIntegration: false,
        sandbox: false,
        webviewTag: false,
        spellcheck: false,
        devTools: !app.isPackaged,
      },
    };
    const icon = iconPath();
    if (icon) opts.icon = icon;

    win = new BrowserWindow(opts);
    if (app.isPackaged) hardenWindow(win);
    const pageUrl = pathToFileURL(page).href;
    win.loadURL(pageUrl).catch(() => win.loadFile(page));
    win.on('closed', () => {
      win = null;
    });
  }

  function sendStatus(payload) {
    if (win && !win.isDestroyed()) {
      win.webContents.send('status', payload);
    }
  }

  async function refreshStatus() {
    const install = findGameInstall();
    const running = await isGameRunning();
    const enabled = install ? isModEnabled(install.gameDir) : false;
    sendStatus({
      gameFound: Boolean(install),
      gameDir: install ? install.gameDir : '',
      steamPath: install ? install.steamPath : '',
      running,
      modEnabled: enabled,
      modSource: getModSourceDir(),
      busy,
      launching,
    });
  }

  function spawnCleanupWatcher(gameDir) {
    const args = app.isPackaged
      ? ['--needle-cleanup', gameDir]
      : [path.join(__dirname, '..'), '--needle-cleanup', gameDir];
    const child = spawn(process.execPath, args, {
      detached: true,
      stdio: 'ignore',
      windowsHide: true,
      env: { ...process.env },
    });
    child.unref();
  }

  async function startCoop() {
    if (busy || launching) return { ok: false, error: t('please_wait') };
    busy = true;
    await refreshStatus();

    try {
      const install = findGameInstall();
      if (!install) {
        return { ok: false, error: t('demo_missing') };
      }

      if (await isGameRunning()) {
        return { ok: false, error: t('game_already_running') };
      }

      launching = true;
      const result = enableMod(install.gameDir, getModSourceDir());
      if (!result.ok) {
        launching = false;
        return result;
      }

      try {
        const mpRoot = path.join(
          process.env.USERPROFILE || '',
          'AppData',
          'LocalLow',
          'lionderwahre',
          'findtheneedle',
          'multiplayer',
        );
        fs.mkdirSync(mpRoot, { recursive: true });
        const flag = path.join(mpRoot, 'auto_open');
        if (fs.existsSync(flag)) fs.rmSync(flag, { force: true });
      } catch (_) {}

      const steamExe = path.join(install.steamPath, 'steam.exe');
      if (fs.existsSync(steamExe)) {
        spawn(steamExe, ['-applaunch', '5165210'], {
          detached: true,
          stdio: 'ignore',
        }).unref();
      } else {
        await shell.openExternal('steam://rungameid/5165210');
      }

      spawnCleanupWatcher(install.gameDir);

      setTimeout(() => {
        app.quit();
      }, 800);

      return { ok: true };
    } catch (e) {
      launching = false;
      return { ok: false, error: String(e && e.message ? e.message : e) };
    } finally {
      busy = false;
      try {
        await refreshStatus();
      } catch (_) {}
    }
  }

  async function stopCoop() {
    const install = findGameInstall();
    if (!install) return { ok: false, error: t('game_not_found') };
    const r = disableMod(install.gameDir);
    await refreshStatus();
    return r;
  }

  app.on('second-instance', () => {
    if (win) {
      if (win.isMinimized()) win.restore();
      win.show();
      win.focus();
    } else if (app.isReady()) {
      createWindow();
    }
  });

  app.whenReady().then(async () => {
    try {
      const install = findGameInstall();
      if (install && !(await isGameRunning())) {
        disableMod(install.gameDir);
      }
    } catch (_) {}

    createWindow();
    booting = false;
    await refreshStatus();

    app.on('activate', () => {
      if (BrowserWindow.getAllWindows().length === 0) createWindow();
    });
  });

  app.on('window-all-closed', async () => {
    if (booting) return;
    if (!launching) {
      try {
        const install = findGameInstall();
        if (install && !(await isGameRunning())) {
          disableMod(install.gameDir);
        }
      } catch (_) {}
    }
    if (process.platform !== 'darwin') app.quit();
  });

  ipcMain.handle('get-status', async () => {
    await refreshStatus();
    return true;
  });

  ipcMain.handle('start-coop', async () => startCoop());
  ipcMain.handle('stop-coop', async () => stopCoop());

  ipcMain.handle('open-game-folder', async () => {
    const install = findGameInstall();
    if (!install) return { ok: false, error: t('game_not_found') };
    shell.openPath(install.gameDir);
    return { ok: true };
  });

  ipcMain.handle('pick-game-folder', async () => {
    const res = await dialog.showOpenDialog(win, {
      title: t('pick_folder_title'),
      properties: ['openDirectory'],
    });
    if (res.canceled || !res.filePaths[0]) return { ok: false };
    const dir = res.filePaths[0];
    const exe = path.join(dir, 'FindTheNeedle.exe');
    if (!fs.existsSync(exe)) {
      return { ok: false, error: t('no_exe_in_folder') };
    }
    const marker = path.join(app.getPath('userData'), 'game-dir.txt');
    fs.writeFileSync(marker, dir, 'utf8');
    await refreshStatus();
    return { ok: true, gameDir: dir };
  });
}
