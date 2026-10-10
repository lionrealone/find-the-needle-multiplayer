const AUTHOR = 'lionderwahre';
const btn = document.getElementById('btnStart');
const msg = document.getElementById('msg');
const lede = document.querySelector('.lede');

function t(key) {
  return window.needle.t(key);
}

function applyStaticUi() {
  document.documentElement.lang = window.needle.lang();
  if (lede) lede.textContent = t('lede');
  btn.textContent = t('start');
}

function setMsg(text, ok) {
  msg.textContent = text || '';
  msg.classList.toggle('ok', Boolean(ok));
}

function paint(s) {
  if (!s) return;
  btn.disabled = Boolean(s.busy) || Boolean(s.launching) || !s.gameFound || s.running;
  if (!s.gameFound) {
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

void AUTHOR;
applyStaticUi();
window.needle.onStatus(paint);
window.needle.getStatus();
btn.addEventListener('click', startNow);
