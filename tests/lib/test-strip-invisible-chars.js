#!/usr/bin/env node
/*
 * tests/lib/test-strip-invisible-chars.js
 *
 * gas-template/utils/gmail.js の stripInvisibleChars を Node から評価し、
 * 不可視文字（ゼロ幅・書式制御・BOM）に加え Unicode タグ文字
 * (U+E0000–U+E007F, プロンプトインジェクションに悪用例あり) を除去すること、
 * 通常文字（多バイト・絵文字）は保持することを検証する (#145)。
 *
 * 設計: test-plaintext-html-render.js と同じく new Function でグローバル関数を抽出。
 *
 * Usage:
 *   node tests/lib/test-strip-invisible-chars.js
 */

const fs = require('fs');
const path = require('path');
const assert = require('assert');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const GMAIL_UTILS = path.join(REPO_ROOT, 'gas-template', 'utils', 'gmail.js');
const source = fs.readFileSync(GMAIL_UTILS, 'utf8');

function loadHelpers() {
  const factory = new Function(
    source + '\nreturn { stripInvisibleChars: typeof stripInvisibleChars === "function" ? stripInvisibleChars : null };'
  );
  return factory();
}

const cases = [];
function test(name, fn) { cases.push({ name, fn }); }

const helpers = loadHelpers();
const strip = helpers.stripInvisibleChars;

if (typeof strip !== 'function') {
  console.error('FAIL: stripInvisibleChars is not defined in gas-template/utils/gmail.js');
  process.exit(1);
}

// --- Unicode タグ文字 (補助面) の除去 ---

test('タグ文字 U+E0041 を除去する', () => {
  assert.strictEqual(strip('A\u{E0041}B'), 'AB');
});

test('タグ範囲の端 U+E0000 / U+E007F を除去する', () => {
  assert.strictEqual(strip('x\u{E0000}y\u{E007F}z'), 'xyz');
});

test('タグ文字で綴った隠し命令を丸ごと除去する', () => {
  // "ignore" を tag 文字で表現した擬似プロンプトインジェクション
  const hidden = '\u{E0069}\u{E0067}\u{E006E}\u{E006F}\u{E0072}\u{E0065}';
  assert.strictEqual(strip('hello' + hidden + 'world'), 'helloworld');
});

// --- 既存対象範囲の回帰 ---

test('ゼロ幅スペース U+200B を除去する（回帰）', () => {
  assert.strictEqual(strip('a​b'), 'ab');
});

test('BOM U+FEFF を除去する（回帰）', () => {
  assert.strictEqual(strip('﻿head'), 'head');
});

test('方向制御文字 U+202E を除去する（回帰）', () => {
  assert.strictEqual(strip('x‮y'), 'xy');
});

// --- 通常文字の保持 ---

test('日本語・ASCII はそのまま保持する', () => {
  assert.strictEqual(strip('日本語 plain text'), '日本語 plain text');
});

test('絵文字 (U+1F600) は除去しない', () => {
  assert.strictEqual(strip('hi 😀 there'), 'hi 😀 there');
});

test('null / undefined / 空文字は空文字を返す', () => {
  assert.strictEqual(strip(null), '');
  assert.strictEqual(strip(undefined), '');
  assert.strictEqual(strip(''), '');
});

// --- 実行 ---

let pass = 0, fail = 0;
for (const c of cases) {
  try {
    c.fn();
    pass++;
    console.log(`  \x1b[32m✓\x1b[0m ${c.name}`);
  } catch (err) {
    fail++;
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
