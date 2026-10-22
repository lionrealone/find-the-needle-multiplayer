const AUTHOR = 'lionrealone';
const fs = require('fs');
const path = require('path');
const { t } = require('./i18n');

const AUTOLOAD_KEY = 'MPMod';
const AUTOLOAD_VALUE = '*mods/multiplayer/mp.gd';
const MARKER = '; lionrealone';
const ALL_MARKERS = [MARKER, '; lionderwahre'];

function hasModMarker(text) {
  const src = String(text || '');
  return ALL_MARKERS.some((m) => src.includes(m));
}

function getModSourceDir() {
  if (process.resourcesPath) {
    const packed = path.join(process.resourcesPath, 'multiplayer');
    if (fs.existsSync(path.join(packed, 'mp.gd'))) return packed;
  }

  const dev = path.join(__dirname, '..', 'resources', 'multiplayer');
  if (fs.existsSync(path.join(dev, 'mp.gd'))) return dev;

  const desktop = path.join(
    process.env.USERPROFILE || '',
    'Desktop',
    'mods',
    'multiplayer',
  );
  if (fs.existsSync(path.join(desktop, 'mp.gd'))) return desktop;

  return dev;
}

function copyDir(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const from = path.join(src, entry.name);
    const to = path.join(dest, entry.name);
    if (entry.isDirectory()) copyDir(from, to);
    else fs.copyFileSync(from, to);
  }
}

function readCfg(file) {
  let text = fs.readFileSync(file, 'utf8');
  if (text.charCodeAt(0) === 0xfeff) text = text.slice(1);
  text = text.replace(/^\uFEFF/, '');
  return text;
}

function writeCfg(file, text) {
  const clean = String(text).replace(/^\uFEFF/, '').replace(/\r\n/g, '\n');
  fs.writeFileSync(file, clean, { encoding: 'utf8' });
}

function ensureBackup(gameDir) {
  const cfg = path.join(gameDir, 'override.cfg');
  const bak = path.join(gameDir, 'override.cfg.needle-backup');
  if (fs.existsSync(cfg) && !fs.existsSync(bak)) {
    const raw = readCfg(cfg);
    if (!raw.includes(AUTOLOAD_KEY) && !hasModMarker(raw)) {
      writeCfg(bak, raw);
    }
  }
  return { cfg, bak };
}

function baseRenderingFrom(text) {
  const src = String(text || '');
  if (/\[rendering\]/i.test(src)) {
    const m = src.match(/\[rendering\][\s\S]*?(?=\n\[|$)/i);
    if (m) {
      let block = m[0].trim();
      block = block.replace(
        /driver\/threads\/thread_model\.template\s*=\s*\d+/g,
        'driver/threads/thread_model.template=0',
      );
      if (!/driver\/threads\/thread_model\.template/.test(block)) {
        block += '\ndriver/threads/thread_model.template=0';
      }
      return block;
    }
  }
  return `[rendering]
rendering_device/driver.windows="d3d12"
rendering_device/fallback_to_vulkan=true
rendering_device/fallback_to_d3d12=false
rendering_device/fallback_to_opengl3=false
driver/threads/thread_model.template=0`;
}

function stripModAutoload(text) {
  const lines = String(text || '')
    .replace(/^\uFEFF/, '')
    .replace(/\r\n/g, '\n')
    .split('\n');
  const out = [];
  let inAutoload = false;
  let autoloadHadOther = false;
  let pendingAutoloadHeader = null;

  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      if (inAutoload && pendingAutoloadHeader && autoloadHadOther) {
        out.push(pendingAutoloadHeader);
      }
      inAutoload = trimmed.toLowerCase() === '[autoload]';
      pendingAutoloadHeader = inAutoload ? line : null;
      autoloadHadOther = false;
      if (!inAutoload) out.push(line);
      continue;
    }

    if (inAutoload) {
      if (
        trimmed.startsWith(`${AUTOLOAD_KEY}=`) ||
        ALL_MARKERS.some((m) => trimmed.includes(m))
      ) {
        continue;
      }
      if (trimmed === '' || trimmed.startsWith(';') || trimmed.startsWith('#')) {
        continue;
      }
      if (!autoloadHadOther && pendingAutoloadHeader) {
        out.push(pendingAutoloadHeader);
        pendingAutoloadHeader = null;
      }
      autoloadHadOther = true;
      out.push(line);
      continue;
    }

    out.push(line);
  }

  if (inAutoload && pendingAutoloadHeader && autoloadHadOther) {
    out.push(pendingAutoloadHeader);
  }

  let joined = out.join('\n');
  joined = joined.replace(/\n{3,}/g, '\n\n').replace(/^\n+/, '').replace(/\n+$/, '\n');
  return joined;
}

function buildEnabledCfg(currentText) {
  const rendering = baseRenderingFrom(currentText);
  return `${rendering}\n\n[autoload]\n${AUTOLOAD_KEY}="${AUTOLOAD_VALUE}" ${MARKER}\n`;
}

function buildDisabledCfg(currentText, bakText) {
  const source = bakText || stripModAutoload(currentText || '');
  return `${baseRenderingFrom(source)}\n`;
}

function isModEnabled(gameDir) {
  const cfg = path.join(gameDir, 'override.cfg');
  if (!fs.existsSync(cfg)) return false;
  const text = readCfg(cfg);
  return text.includes(`${AUTOLOAD_KEY}=`) && text.includes('mods/multiplayer/mp.gd');
}

function enableMod(gameDir, modSource) {
  try {
    if (!fs.existsSync(path.join(modSource, 'mp.gd'))) {
      return { ok: false, error: `Mod-Quelle fehlt: ${modSource}` };
    }

    ensureBackup(gameDir);

    const dest = path.join(gameDir, 'mods', 'multiplayer');
    fs.rmSync(dest, { recursive: true, force: true });
    copyDir(modSource, dest);

    const cfgPath = path.join(gameDir, 'override.cfg');
    const current = fs.existsSync(cfgPath) ? readCfg(cfgPath) : '';
    writeCfg(cfgPath, buildEnabledCfg(current));

    return { ok: true };
  } catch (e) {
    const msg = String(e && e.message ? e.message : e);
    if (/EPERM|EACCES|denied/i.test(msg)) {
      return { ok: false, error: t('no_write_access') };
    }
    return { ok: false, error: msg };
  }
}

function disableMod(gameDir) {
  try {
    const cfg = path.join(gameDir, 'override.cfg');
    const bak = path.join(gameDir, 'override.cfg.needle-backup');
    const current = fs.existsSync(cfg) ? readCfg(cfg) : '';
    const bakText = fs.existsSync(bak) ? readCfg(bak) : '';
    writeCfg(cfg, buildDisabledCfg(current, bakText));
    return { ok: true };
  } catch (e) {
    const msg = String(e && e.message ? e.message : e);
    if (/EPERM|EACCES|denied/i.test(msg)) {
      return { ok: false, error: t('disable_failed') };
    }
    return { ok: false, error: msg };
  }
}

module.exports = {
  getModSourceDir,
  enableMod,
  disableMod,
  isModEnabled,
};
