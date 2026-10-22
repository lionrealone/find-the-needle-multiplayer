const AUTHOR = 'lionrealone';
const btn = document.getElementById('btnStart');
const btnPick = document.getElementById('btnPick');
const btnSteam = document.getElementById('btnSteam');
const actions = document.getElementById('actions');
const msg = document.getElementById('msg');
const lede = document.querySelector('.lede');

function t(key) {
  return window.needle.t(key);
}

function applyStaticUi() {
  document.documentElement.lang = window.needle.lang();
  if (lede) lede.textContent = t('lede');
  btn.textContent = t('start');
  if (btnPick) btnPick.textContent = t('pick_folder');
  if (btnSteam) btnSteam.textContent = t('open_steam_demo');
}

function setMsg(text, ok) {
  msg.textContent = text || '';
  msg.classList.toggle('ok', Boolean(ok));
}

function paint(s) {
  if (!s) return;
  const missing = !s.gameFound;
  if (actions) actions.hidden = !missing;
  btn.disabled =
    Boolean(s.busy) || Boolean(s.launching) || missing || s.running;
  if (missing) {
    setMsg(t('demo_missing'));
  } else if (s.running) {
    setMsg(t('game_running'), true);
  } else if (s.launching) {
    setMsg(t('game_starting'), true);
  } else {
    setMsg('');
  }
}

async function startNow() {
  setMsg(t('starting'));
  btn.disabled = true;
  const res = await window.needle.startCoop();
  if (res && res.ok) setMsg(t('game_starting'), true);
  else {
    setMsg((res && res.error) || t('start_failed'));
    btn.disabled = false;
  }
}

async function pickFolder() {
  const res = await window.needle.pickGameFolder();
  if (!res) return;
  if (res.ok) {
    setMsg(t('folder_saved'), true);
    await window.needle.getStatus();
  } else if (res.error) {
    setMsg(res.error);
  }
}

async function openSteamDemo() {
  await window.needle.openSteamDemo();
}

void AUTHOR;
applyStaticUi();
window.needle.onStatus(paint);
window.needle.getStatus();
btn.addEventListener('click', startNow);
if (btnPick) btnPick.addEventListener('click', pickFolder);
if (btnSteam) btnSteam.addEventListener('click', openSteamDemo);
