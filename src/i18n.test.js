'use strict';

const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const { STRINGS } = require('./i18n');

function srcJsFiles(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === 'node_modules') continue;
      srcJsFiles(full, out);
    } else if (
      entry.name.endsWith('.js') &&
      !/(_test|\.test\.)/.test(entry.name)
    ) {
      out.push(full);
    }
  }
  return out;
}

function tKeysUsedInSource() {
  const keys = new Set();
  const re = /\bt\(\s*['"]([a-z0-9_]+)['"]\s*\)/gi;
  for (const file of srcJsFiles(path.join(__dirname))) {
    const text = fs.readFileSync(file, 'utf8');
    for (const m of text.matchAll(re)) keys.add(m[1]);
  }
  return [...keys];
}

test('every t(key) used in src exists in en and de string tables', () => {
  const used = tKeysUsedInSource();
  assert.ok(used.length >= 10, `expected a realistic set of keys, got ${used.length}`);
  for (const key of used) {
    assert.ok(
      STRINGS.en[key] != null,
      `key '${key}' missing from STRINGS.en`,
    );
    assert.ok(
      STRINGS.de[key] != null,
      `key '${key}' missing from STRINGS.de`,
    );
  }
});

test('demo_missing and no_exe_in_folder carry no demo wording', () => {
  for (const code of ['en', 'de']) {
    for (const key of ['demo_missing', 'no_exe_in_folder']) {
      assert.doesNotMatch(
        STRINGS[code][key],
        /demo/i,
        `STRINGS.${code}.${key} still mentions the demo`,
      );
    }
  }
});
