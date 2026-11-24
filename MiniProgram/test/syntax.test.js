const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');

// WeChat DevTools (base library 3.17.x, es6 compile) silently drops a module that contains an optional call `?.(`, a
// logical assignment (`??=`, `||=`, `&&=`), a #private field or a class field (`static x = 1;`, `x = [];` in a class body):
// its es6 transform has no class-properties support. Node accepts all of them, so only this test catches them.
const root = process.env.MINI_ROOT || path.join(__dirname, '..');
const sources = fs.readdirSync(root).filter((f) => f.endsWith('.js'));

// The example's own files (MiniProgram/example/miniprogram/**/*.js). `cyl/` is the library copy that `sync.sh` creates (git-ignored).
const exampleRoot = path.join(root, 'example', 'miniprogram');
function exampleFiles(dir = exampleRoot) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    const full = path.join(dir, e.name);
    if (e.isDirectory()) return e.name === 'cyl' ? [] : exampleFiles(full);
    return e.name.endsWith('.js') ? [path.relative(root, full)] : [];
  });
}
const exampleSources = exampleFiles();

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

function checkSyntax(file) {
  const text = code(file);
  assert.deepEqual(classFields(text), [], `${file}: class field(s); assign in the constructor or after the class`);
  for (const [pattern, name] of forbidden) {
    const m = text.match(pattern);
    assert.equal(m, null, `${file}: ${name} found near "${m && text.slice(Math.max(0, m.index - 30), m.index + 40).replace(/\n/g, ' ')}"`);
  }
}

for (const file of sources) {
  test(`${file} has no syntax that WeChat DevTools drops`, () => checkSyntax(file));
}

// The example is compiled by the same DevTools: its own files obey the same rules.
test('the example has files to check (its own, not the synced library copy)', () => {
  assert.ok(exampleSources.length >= 3, `found ${exampleSources.join(', ')}`);
  assert.ok(exampleSources.every((f) => !f.includes(`${path.sep}cyl${path.sep}`)), 'the synced library copy must not be scanned here');
});

for (const file of exampleSources) {
  test(`${file} has no syntax that WeChat DevTools drops`, () => checkSyntax(file));
  test(`${file} requires with plain statically analyzable calls`, () => {
    const text = code(file);
    assert.equal(/\.\.\.\s*require\s*\(/.test(text), false, `${file}: \`...require(\` is not followed by DevTools`);
    const raw = fs.readFileSync(path.join(root, file), 'utf8');
    assert.equal(/require\(\s*'\.{1,2}\/[^']*\.js'\s*\)/.test(raw), false, `${file}: use require('./name') without the .js extension`);
    assert.equal(/require\(\s*[^'\s)]/.test(raw.replace(/\/\/.*$/gm, '')), false, `${file}: require() takes a string literal only`);
  });
}

// WeChat DevTools drops every file it cannot see referenced (ignoreDevUnusedFiles is on by default) and does not follow
// `...require('./x')` in an object spread: index.js must reach every module through plain `require('./name')` calls.
test('index.js uses no spread-require', () => {
  assert.equal(/\.\.\.\s*require\s*\(/.test(code('index.js')), false, 'index.js: `...require(` is not followed by DevTools');
});

test('every module is reachable from index.js by a plain require chain', () => {
  const reachable = new Set(['index.js']);
  const queue = ['index.js'];
  while (queue.length) {
    const file = queue.shift();
    const text = fs.readFileSync(path.join(root, file), 'utf8');
    for (const m of text.matchAll(/(?<![.\w])require\(\s*'\.\/([\w-]+)(?:\.js)?'\s*\)/g)) {
      const next = `${m[1]}.js`;
      if (!reachable.has(next) && sources.includes(next)) { reachable.add(next); queue.push(next); }
    }
  }
  assert.deepEqual(sources.filter((f) => !reachable.has(f)).sort(), [], 'files DevTools would drop as unused');
});

test('internal requires omit the .js extension', () => {
  for (const file of sources) {
    assert.equal(/require\(\s*'\.\/[\w-]+\.js'\s*\)/.test(fs.readFileSync(path.join(root, file), 'utf8')), false, `${file}: use require('./name')`);
  }
});
