const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');

// WeChat DevTools (base library 3.17.x, es6 compile) silently drops a module that contains an optional call `?.(`, a
// logical assignment (`??=`, `||=`, `&&=`) or a #private field; Node accepts them, so only this test catches them.
const root = path.join(__dirname, '..');
const sources = fs.readdirSync(root).filter((f) => f.endsWith('.js'));

function code(file) {
  return fs.readFileSync(path.join(root, file), 'utf8')
    .replace(/\/\*[\s\S]*?\*\//g, '')              // block comments
    .replace(/(^|[^:'"`\\])\/\/.*$/gm, '$1')       // line comments
    .replace(/'(?:\\.|[^'\\\n])*'/g, "''")         // strings
    .replace(/"(?:\\.|[^"\\\n])*"/g, '""')
    .replace(/`(?:\\.|[^`\\])*`/g, '``');
}

const forbidden = [
  [/\?\.\(/, 'optional call `?.(`'],
  [/\?\?=|\|\|=|&&=/, 'logical assignment `??=` / `||=` / `&&=`'],
  [/(^|[\s(,{;])#[A-Za-z_$]/m, '#private field'],
  [/\bthis\.#/, '#private member access'],
];

test('there are mini program sources to check', () => {
  assert.ok(sources.length >= 5, `found ${sources.join(', ')}`);
});

for (const file of sources) {
  test(`${file} has no syntax that WeChat DevTools drops`, () => {
    const text = code(file);
    for (const [pattern, name] of forbidden) {
      const m = text.match(pattern);
      assert.equal(m, null, `${file}: ${name} found near "${m && text.slice(Math.max(0, m.index - 30), m.index + 40).replace(/\n/g, ' ')}"`);
    }
  });
}
