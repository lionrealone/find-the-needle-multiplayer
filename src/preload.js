const AUTHOR = 'lionderwahre';
const { contextBridge, ipcRenderer } = require('electron');
const { t, lang } = require('./i18n');

contextBridge.exposeInMainWorld('needle', {
  author: AUTHOR,
  t: (key) => t(key),
  lang: () => lang(),
  getStatus: () => ipcRenderer.invoke('get-status'),
  startCoop: () => ipcRenderer.invoke('start-coop'),
  stopCoop: () => ipcRenderer.invoke('stop-coop'),
  openGameFolder: () => ipcRenderer.invoke('open-game-folder'),
  pickGameFolder: () => ipcRenderer.invoke('pick-game-folder'),
  onStatus: (cb) => {
    const handler = (_e, data) => cb(data);
    ipcRenderer.on('status', handler);
    return () => ipcRenderer.removeListener('status', handler);
  },
  onAutoStart: (cb) => {
    const handler = (_e, data) => cb(data);
    ipcRenderer.on('auto-start', handler);
    return () => ipcRenderer.removeListener('auto-start', handler);
  },
});
