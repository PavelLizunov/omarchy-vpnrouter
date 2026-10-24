const assert = require('assert');
const fs = require('fs');
const path = require('path');
const moduleShim = {exports: {}};
new Function('module', fs.readFileSync(path.join(__dirname, '../lib/Model.js'), 'utf8').replace(/^\.pragma library\s*/m, ''))(moduleShim);
const {runningApplications} = moduleShim.exports;
const data = {runningApps: [
  {name: 'chatgpt', displayName: 'ChatGPT', desktopId: 'chatgpt.desktop'},
  {name: 'chromium', desktopId: 'chromium.desktop'},
  {name: 'com.discordapp.Discord', displayName: 'Discord', desktopId: 'com.discordapp.Discord.desktop'},
  {name: 'dropbox', desktopId: 'dropbox.desktop'},
  {name: 'nvim', desktopId: 'nvim.desktop'},
  {name: 'org.mozilla.Thunderbird', displayName: 'Thunderbird', desktopId: 'org.mozilla.Thunderbird.desktop'},
  ...['bash', 'cat', 'at-spi-bus-launcher', 'codex', 'bwrap'].map(name => ({name}))
]};
const names = list => list.map(app => app.name).sort();
const gui = windows => runningApplications(data, '', windows).filter(app => app.desktopId || app.hasWindow);
assert.strictEqual(gui([]).length, 6, 'Only desktop apps appear by default without windows');
assert.deepStrictEqual(names(runningApplications(data, '', []).filter(app => !app.desktopId && !app.hasWindow)), ['at-spi-bus-launcher', 'bash', 'bwrap', 'cat', 'codex']);
assert.strictEqual(gui([{lastIpcObject: {class: 'CODEX'}}]).length, 7, 'A window class promotes a process without changing its match name');
assert.strictEqual(gui([{wayland: {appId: 'codex'}}]).length, 7, 'Wayland appId works before IPC metadata is populated');
assert.strictEqual(gui([{lastIpcObject: {initialClass: 'codex'}}]).length, 7);
assert.strictEqual(gui([{lastIpcObject: {class: 'codex-helper'}}]).length, 6, 'No substring false positives');
assert.strictEqual(gui([null, {}]).length, 6);
assert.strictEqual(gui([]).length, 6, 'Closing a window demotes the process');
assert.deepStrictEqual(names(runningApplications(data, 'CoDeX', [])), ['codex'], 'Search includes processes without desktop or windows');
assert.deepStrictEqual(names(runningApplications(data, 'discord', [])), ['com.discordapp.Discord']);
assert.deepStrictEqual(runningApplications({running: ['bash']}, '', []), [], 'Legacy lists retain manual fallback');
const pidApps = {runningApps: [{name:'unique',pid:42}, {name:'multi',pids:[43,44]}, {name:'unknown',pid:0}, {name:'stale',hasWindow:true}]};
const pidResult = runningApplications(pidApps, '', [{lastIpcObject:{pid:42}}, {lastIpcObject:{pid:44}}, {lastIpcObject:{pid:0}}]);
assert.deepStrictEqual(names(pidResult.filter(app => app.hasWindow)), ['multi','unique']);
assert.strictEqual(pidApps.runningApps[3].hasWindow, true, 'Local windows override stale peer hints without mutating data');
console.log('PASS: desktop/window partition, IPC class/initialClass/Wayland appId, optional pid/pids, close, search and legacy fallback');
