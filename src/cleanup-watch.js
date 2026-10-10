const AUTHOR = 'lionderwahre';
const { execFile } = require('child_process');
const { disableMod } = require('./mod');

function running() {
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
          if (name.toLowerCase() === 'findtheneedle.exe') {
            resolve(true);
            return;
          }
        }
        resolve(false);
      },
    );
  });
}

function runCleanupWatch(gameDir) {
  return new Promise((resolve) => {
    if (!gameDir) {
      resolve();
      return;
    }
    let seen = false;
    const started = Date.now();

    async function finish() {
      try {
        disableMod(gameDir);
      } catch (_) {}
      resolve();
    }

    async function tick() {
      const on = await running();
      if (on) seen = true;
      if (seen && !on) {
        await finish();
        return;
      }
      if (!seen && Date.now() - started > 180000) {
        await finish();
        return;
      }
      setTimeout(tick, 2000);
    }

    setTimeout(tick, 5000);
  });
}

module.exports = { runCleanupWatch };

if (require.main === module) {
  const gameDir = process.argv[2];
  runCleanupWatch(gameDir).then(() => process.exit(0));
}
