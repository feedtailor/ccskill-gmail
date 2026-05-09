#!/usr/bin/env node
/*
 * tests/lib/test-plaintext-html-render.js
 *
 * gas-template/utils/gmail.js の isLikelyPlainTextOnly_ ヘルパーを
 * Node から評価して heuristic の正しさを検証する。
 *
 * 設計: gas-template の JS は GAS グローバル前提で module.exports を持たない。
 *       そのため、ファイル内容を読み出して new Function で対象関数を抽出する。
 *
 * Usage:
 *   node tests/lib/test-plaintext-html-render.js
 */

const fs = require('fs');
const path = require('path');
const assert = require('assert');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const GMAIL_UTILS = path.join(REPO_ROOT, 'gas-template', 'utils', 'gmail.js');

const source = fs.readFileSync(GMAIL_UTILS, 'utf8');

// gas-template の関数を Node コンテキストで評価する。
// ファイル全体を function body にして、必要な関数を return する。
function loadHelpers() {
  const factory = new Function(
    source + '\nreturn { isLikelyPlainTextOnly_: typeof isLikelyPlainTextOnly_ === "function" ? isLikelyPlainTextOnly_ : null };'
  );
  return factory();
}

const cases = [];
function test(name, fn) { cases.push({ name, fn }); }

const helpers = loadHelpers();
const isPlain = helpers.isLikelyPlainTextOnly_;

if (typeof isPlain !== 'function') {
  console.error('FAIL: isLikelyPlainTextOnly_ is not defined in gas-template/utils/gmail.js');
  process.exit(1);
}

// --- プレーンテキスト判定が true になるケース ---

test('お名前.com 領収書のような罫線・全角スペース桁揃えメール', () => {
  var body =
    '━━お名前.com by GMO ━━━━━━━━━━━━━━━━━━━━━━━━\n\n' +
    '───────────────────────────────────\n' +
    '■ドメイン更新料金ご請求明細／領収書■\n' +
    '───────────────────────────────────\n\n' +
    '[明細情報]\n' +
    'ご請求書番号................：27695284\n' +
    '請求書発行日................：2026年05月02日\n' +
    'お支払い金額合計（税込）....：2,194円\n';
  assert.strictEqual(isPlain(body), true);
});

test('単純な改行混じりプレーンテキスト', () => {
  assert.strictEqual(isPlain('Hello\nThis is a plain text email.\nRegards.'), true);
});

test('空文字列は plain 扱い', () => {
  assert.strictEqual(isPlain(''), true);
});

test('null / undefined は plain 扱い', () => {
  assert.strictEqual(isPlain(null), true);
  assert.strictEqual(isPlain(undefined), true);
});

// --- HTML メール判定が false になるケース ---

test('<div> を含む HTML メール', () => {
  assert.strictEqual(isPlain('<div>Hello</div><p>Body</p>'), false);
});

test('<br> 改行入りの HTML メール', () => {
  assert.strictEqual(isPlain('Line 1<br>Line 2<br>Line 3'), false);
});

test('table を含む HTML メール', () => {
  assert.strictEqual(isPlain('<table><tr><td>cell</td></tr></table>'), false);
});

test('<p> 段落の HTML メール', () => {
  assert.strictEqual(isPlain('<p>First paragraph.</p><p>Second.</p>'), false);
});

test('<a href> リンク含みの HTML メール', () => {
  assert.strictEqual(isPlain('Visit <a href="https://example.com">example</a> for details.'), false);
});

test('<img> 画像入りメール', () => {
  assert.strictEqual(isPlain('<img src="cid:foo"/>'), false);
});

test('<blockquote> を含むメール', () => {
  assert.strictEqual(isPlain('<blockquote>quoted</blockquote>'), false);
});

test('<ul><li> リストのメール', () => {
  assert.strictEqual(isPlain('<ul><li>item</li></ul>'), false);
});

test('見出し <h1> 含みメール', () => {
  assert.strictEqual(isPlain('<h1>Title</h1>plain after'), false);
});

// --- エッジケース ---

test('テキスト中に "<3" のような不等号があってもタグでなければ plain 扱い', () => {
  assert.strictEqual(isPlain('I love this <3 so much\n2 < 3 is true'), true);
});

test('case-insensitive で <DIV> も HTML 判定', () => {
  assert.strictEqual(isPlain('<DIV>upper</DIV>'), false);
});

// --- 実行 ---

let pass = 0, fail = 0;
const failures = [];

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
