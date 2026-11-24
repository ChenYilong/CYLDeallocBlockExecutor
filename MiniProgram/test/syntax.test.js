const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');

// WeChat DevTools (base library 3.17.x, es6 compile) silently drops a module that contains an optional call `?.(`, a
// logical assignment (`??=`, `||=`, `&&=`), a #private field or a class field (`static x = 1;`, `x = [];` in a class body):
// its es6 transform has no class-properties support. Node accepts all of them, so only this test catches them.
const root = process.env.MINI_ROOT || path.join(__dirname, '..');
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
  [/\?\?/, 'nullish coalescing `??`'],
  [/\?\./, 'optional chaining `?.`'],
  [/\bcatch\s*\{/, 'optional catch binding `catch {`'],
];

// Class fields: at depth 1 of a class body, a line that starts a member without a `(` before `=` / `;`.
function classFields(text) {
  const found = [];
  const re = /\bclass\s+[A-Za-z_$][\w$]*(?:\s+extends\s+[\w$.]+)?\s*\{/g;
  let m;
  while ((m = re.exec(text))) {
    let depth = 1;
    let i = re.lastIndex;
    let statementStart = i;
    while (i < text.length && depth > 0) {
      const ch = text[i];
      if (ch === '{') { if (depth === 1) { /* method body start */ } depth++; }
      else if (ch === '}') { depth--; if (depth === 1) statementStart = i + 1; }
      else if (depth === 1 && ch === ';') {
        const stmt = text.slice(statementStart, i + 1).trim();
        if (/^(static\s+)?[A-Za-z_$][\w$]*\s*(=|;)/.test(stmt)) found.push(stmt.slice(0, 50));
        statementStart = i + 1;
      }
      i++;
    }
  }
  return found;
}

test('there are mini program sources to check', () => {
  assert.ok(sources.length >= 5, `found ${sources.join(', ')}`);
});

for (const file of sources) {
  test(`${file} has no syntax that WeChat DevTools drops`, () => {
    const text = code(file);
    assert.deepEqual(classFields(text), [], `${file}: class field(s); assign in the constructor or after the class`);
    for (const [pattern, name] of forbidden) {
      const m = text.match(pattern);
      assert.equal(m, null, `${file}: ${name} found near "${m && text.slice(Math.max(0, m.index - 30), m.index + 40).replace(/\n/g, ' ')}"`);
    }
  });
}
