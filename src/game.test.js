'use strict';

const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const target = require('./target');
const { pickAppRoot } = require('./target');

test('APP_ID is the Steam release app id', () => {
  assert.strictEqual(target.APP_ID, '5160800');
});

test('steamLaunchArgs targets the release app id', () => {
  assert.deepStrictEqual(target.steamLaunchArgs(), ['-applaunch', '5160800']);
});

test('steamRunUrl contains the release app id', () => {
  assert.ok(target.steamRunUrl().includes('5160800'));
});

test('isDemoFolderName detects demo folders', () => {
  assert.strictEqual(target.isDemoFolderName('Find The Needle Demo'), true);
  assert.strictEqual(target.isDemoFolderName('FindTheNeedle Demo'), true);
  assert.strictEqual(target.isDemoFolderName('Needle in a Haystack'), false);
  assert.strictEqual(target.isDemoFolderName(''), false);
});

test('isReleaseGameDir accepts a dir with the exe and no demo name', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'needle-target-'));
  const release = path.join(root, 'Needle in a Haystack');
  fs.mkdirSync(release);
  fs.writeFileSync(path.join(release, 'FindTheNeedle.exe'), 'x');
  assert.strictEqual(target.isReleaseGameDir(release), true);
});

test('isReleaseGameDir rejects a demo dir even with the exe inside', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'needle-target-'));
  const demo = path.join(root, 'Find The Needle Demo');
  fs.mkdirSync(demo);
  fs.writeFileSync(path.join(demo, 'FindTheNeedle.exe'), 'x');
  assert.strictEqual(target.isReleaseGameDir(demo), false);
});

test('isReleaseGameDir rejects a dir without the exe', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'needle-target-'));
  assert.strictEqual(target.isReleaseGameDir(root), false);
});

test('every name main.js destructures from ./game is exported by game.js', () => {
  const mainSrc = fs.readFileSync(path.join(__dirname, 'main.js'), 'utf8');
  const gameSrc = fs.readFileSync(path.join(__dirname, 'game.js'), 'utf8');
  const destructure = mainSrc.match(/const\s*\{([^}]*)\}\s*=\s*require\('\.\/game'\)/);
  assert.ok(destructure, 'main.js must destructure from ./game');
  const names = destructure[1].split(',').map((s) => s.trim()).filter(Boolean);
  assert.ok(names.length >= 5, `expected realistic import list, got ${names.length}`);
  for (const name of names) {
    assert.match(
      gameSrc,
      new RegExp(`\\b${name}\\b`),
      `game.js never mentions '${name}' — main.js imports a dead name from ./game`,
    );
  }
});

test('pickAppRoot prefers an app path that has the UI files', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'needle-target-'));
  const appPath = path.join(root, 'app');
  fs.mkdirSync(path.join(appPath, 'renderer'), { recursive: true });
  fs.writeFileSync(path.join(appPath, 'renderer', 'index.html'), 'x');
  fs.writeFileSync(path.join(appPath, 'preload.js'), 'x');
  const srcDir = path.join(root, 'src');
  fs.mkdirSync(srcDir);
  assert.strictEqual(pickAppRoot(appPath, srcDir), appPath);
});

test('pickAppRoot falls back to the src dir when app path lacks the UI', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'needle-target-'));
  const appPath = path.join(root, 'repo-root');
  fs.mkdirSync(appPath);
  const srcDir = path.join(root, 'src');
  fs.mkdirSync(path.join(srcDir, 'renderer'), { recursive: true });
  fs.writeFileSync(path.join(srcDir, 'renderer', 'index.html'), 'x');
  fs.writeFileSync(path.join(srcDir, 'preload.js'), 'x');
  assert.strictEqual(pickAppRoot(appPath, srcDir), srcDir);
});
