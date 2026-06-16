#!/usr/bin/env node
/*
 * tests/lib/test-addr-spec-validation.js
 *
 * gas-template/utils/validation.js の addr-spec 非ASCII 検出ヘルパーを
 * Node から評価して検証する (#127)。
 *
 * 設計: gas-template の JS は GAS グローバル前提で module.exports を持たない。
 *       そのため、ファイル内容を読み出して new Function で対象関数を抽出する
 *       (test-plaintext-html-render.js と同じ方式)。
 *
 * 検証対象:
 *   - splitRecipients_(s)        : 引用符を考慮したカンマ分割
 *   - extractAddrSpec_(elem)     : 1要素から addr-spec 部分を取り出す
 *   - findNonAsciiAddrSpec_(s)   : addr-spec に非ASCII を含む最初の値を返す (無ければ null)
 *
 * 方針: name-addr 形式の display-name の全角は許容し、addr-spec (アドレス本体)
 *       の非ASCII のみを検出する。
 *
 * Usage:
 *   node tests/lib/test-addr-spec-validation.js
 */

const fs = require('fs');
const path = require('path');
const assert = require('assert');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const VALIDATION = path.join(REPO_ROOT, 'gas-template', 'utils', 'validation.js');

const source = fs.readFileSync(VALIDATION, 'utf8');

function loadHelpers() {
  const factory = new Function(
    source +
    '\nreturn {' +
    '  splitRecipients_: typeof splitRecipients_ === "function" ? splitRecipients_ : null,' +
    '  extractAddrSpec_: typeof extractAddrSpec_ === "function" ? extractAddrSpec_ : null,' +
    '  findNonAsciiAddrSpec_: typeof findNonAsciiAddrSpec_ === "function" ? findNonAsciiAddrSpec_ : null' +
    '};'
  );
  return factory();
}

const helpers = loadHelpers();
const split = helpers.splitRecipients_;
const extract = helpers.extractAddrSpec_;
const findBad = helpers.findNonAsciiAddrSpec_;

for (const [name, fn] of [['splitRecipients_', split], ['extractAddrSpec_', extract], ['findNonAsciiAddrSpec_', findBad]]) {
  if (typeof fn !== 'function') {
    console.error(`FAIL: ${name} is not defined in gas-template/utils/validation.js`);
    process.exit(1);
  }
}

const cases = [];
function test(name, fn) { cases.push({ name, fn }); }

// --- splitRecipients_ ---

test('split: 単純なカンマ区切りを2要素に分割', () => {
  assert.deepStrictEqual(split('a@x.com, b@y.com').map(s => s.trim()), ['a@x.com', 'b@y.com']);
});

test('split: 引用符内のカンマでは分割しない (display-name 内カンマ保護)', () => {
  assert.deepStrictEqual(split('"岸田, 様" <a@b.jp>'), ['"岸田, 様" <a@b.jp>']);
});

test('split: 空文字列は空配列', () => {
  assert.deepStrictEqual(split(''), []);
});

// --- extractAddrSpec_ ---

test('extract: name-addr は山括弧内を返す', () => {
  assert.strictEqual(extract('"岸田様" <ok@example.co.jp>').trim(), 'ok@example.co.jp');
});

test('extract: 山括弧なしは要素全体(trim)を返す', () => {
  assert.strictEqual(extract(' a@example.com ').trim(), 'a@example.com');
});

test('extract: 山括弧なしの全角アドレス本体をそのまま返す', () => {
  assert.strictEqual(extract('【要入力】@kishidajim.co.jp').trim(), '【要入力】@kishidajim.co.jp');
});

// --- findNonAsciiAddrSpec_ (本命) ---

test('素のASCIIアドレスは null', () => {
  assert.strictEqual(findBad('a@example.com'), null);
});

test('全角を含む addr-spec を検出する', () => {
  assert.strictEqual(findBad('【要入力】@kishidajim.co.jp'), '【要入力】@kishidajim.co.jp');
});

test('name-addr の日本語 display-name は許容 (null)', () => {
  assert.strictEqual(findBad('"岸田様" <ok@example.co.jp>'), null);
});

test('複数アドレスで全て ASCII なら null', () => {
  assert.strictEqual(findBad('a@x.com, b@y.com'), null);
});

test('複数アドレスで1つが全角 addr-spec なら検出', () => {
  assert.strictEqual(findBad('a@x.com, 【要入力】@y.jp'), '【要入力】@y.jp');
});

test('name-addr 複数で addr-spec が全て ASCII なら null', () => {
  assert.strictEqual(findBad('"A" <a@x.com>, "B様" <b@y.com>'), null);
});

test('display-name 内カンマがあっても addr-spec が ASCII なら null', () => {
  assert.strictEqual(findBad('"岸田, 様" <ok@example.jp>'), null);
});

test('山括弧内 addr-spec に全角があれば検出', () => {
  assert.strictEqual(findBad('"name" <【x】@y.jp>'), '【x】@y.jp');
});

test('空文字列は null', () => {
  assert.strictEqual(findBad(''), null);
});

test('null / undefined は null', () => {
  assert.strictEqual(findBad(null), null);
  assert.strictEqual(findBad(undefined), null);
});

test('前後の空白付き素アドレスは null', () => {
  assert.strictEqual(findBad('  a@example.com  '), null);
});

// --- 実行 ---

let pass = 0, fail = 0;
const failures = [];

console.log('test-addr-spec-validation.js (#127)\n');

for (const c of cases) {
  try {
    c.fn();
    pass++;
    console.log(`  \x1b[32m✓\x1b[0m ${c.name}`);
  } catch (err) {
    fail++;
    failures.push({ name: c.name, err });
    console.log(`  \x1b[31m✗\x1b[0m ${c.name}`);
    console.log(`      ${err.message.split('\n').join('\n      ')}`);
  }
}

console.log('');
console.log('================================================');
if (fail === 0) {
  console.log(`\x1b[32mAll ${pass} tests passed\x1b[0m`);
  process.exit(0);
} else {
  console.log(`\x1b[31m${fail} of ${pass + fail} tests failed\x1b[0m`);
  process.exit(1);
}
