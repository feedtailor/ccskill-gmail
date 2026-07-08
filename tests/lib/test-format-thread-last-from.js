#!/usr/bin/env node
/*
 * tests/lib/test-format-thread-last-from.js
 *
 * gas-template/utils/gmail.js の formatThread に追加する lastFrom
 * （下書きを除いた直近メッセージの送信者）を Node から評価して検証する (#152)。
 *
 * 設計: test-strip-invisible-chars.js と同じく new Function でグローバル関数を抽出し、
 *       モックの GmailThread / GmailMessage オブジェクトを渡す。GAS のライブ API は使わない。
 *
 * Usage:
 *   node tests/lib/test-format-thread-last-from.js
 */

const fs = require('fs');
const path = require('path');
const assert = require('assert');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const GMAIL_UTILS = path.join(REPO_ROOT, 'gas-template', 'utils', 'gmail.js');
const source = fs.readFileSync(GMAIL_UTILS, 'utf8');

function loadHelpers() {
  const factory = new Function(
    source + '\nreturn { formatThread: typeof formatThread === "function" ? formatThread : null };'
  );
  return factory();
}

const cases = [];
function test(name, fn) { cases.push({ name, fn }); }

const helpers = loadHelpers();
const formatThread = helpers.formatThread;

if (typeof formatThread !== 'function') {
  console.error('FAIL: formatThread is not defined in gas-template/utils/gmail.js');
  process.exit(1);
}

// --- モックビルダー ---

function mockMessage(from, opts) {
  opts = opts || {};
  return {
    getFrom: () => from,
    getSubject: () => opts.subject || 'テスト件名',
    getDate: () => opts.date || new Date('2026-07-08T00:00:00Z'),
    isDraft: () => !!opts.isDraft
  };
}

function mockThread(messages, opts) {
  opts = opts || {};
  return {
    getId: () => opts.id || 'thread-1',
    getMessages: () => messages,
    isUnread: () => !!opts.isUnread,
    isImportant: () => !!opts.isImportant,
    isInPriorityInbox: () => !!opts.isInPriorityInbox,
    isInInbox: () => opts.isInInbox !== false,
    getLabels: () => (opts.labels || []).map((name) => ({ getName: () => name }))
  };
}

// --- ケース ---

test('2通とも非下書き: from は最初の送信者、lastFrom は最後の送信者', () => {
  const messages = [
    mockMessage('a@example.com'),
    mockMessage('b@example.com')
  ];
  const result = formatThread(mockThread(messages));
  assert.strictEqual(result.from, 'a@example.com');
  assert.strictEqual(result.lastFrom, 'b@example.com');
});

test('最後が下書き: lastFrom は下書きをスキップし直近の実送信者を返す', () => {
  const messages = [
    mockMessage('a@example.com'),
    mockMessage('b@example.com'),
    mockMessage('me@example.com', { isDraft: true })
  ];
  const result = formatThread(mockThread(messages));
  assert.strictEqual(result.from, 'a@example.com');
  assert.strictEqual(result.lastFrom, 'b@example.com');
});

test('全メッセージが下書き: lastFrom は null（最後のメッセージへフォールバックしない）', () => {
  const messages = [
    mockMessage('me@example.com', { isDraft: true })
  ];
  const result = formatThread(mockThread(messages));
  assert.strictEqual(result.from, 'me@example.com');
  assert.strictEqual(result.lastFrom, null);
});

test('メッセージ1通のみ（非下書き）: from と lastFrom は同一人物', () => {
  const messages = [mockMessage('a@example.com')];
  const result = formatThread(mockThread(messages));
  assert.strictEqual(result.from, 'a@example.com');
  assert.strictEqual(result.lastFrom, 'a@example.com');
});

test('既存フィールド（id/subject/messageCount/labels 等）は変更されない', () => {
  const messages = [
    mockMessage('a@example.com', { subject: '見積の件' }),
    mockMessage('b@example.com', { date: new Date('2026-07-08T09:00:00Z') })
  ];
  const thread = mockThread(messages, {
    id: 'thread-99',
    isUnread: true,
    isImportant: true,
    isInPriorityInbox: false,
    isInInbox: true,
    labels: ['INBOX', 'Important']
  });
  const result = formatThread(thread);
  assert.strictEqual(result.id, 'thread-99');
  assert.strictEqual(result.subject, '見積の件');
  assert.strictEqual(result.messageCount, 2);
  assert.strictEqual(result.isUnread, true);
  assert.strictEqual(result.isImportant, true);
  assert.strictEqual(result.isInPriorityInbox, false);
  assert.strictEqual(result.isInInbox, true);
  assert.deepStrictEqual(result.labels, ['INBOX', 'Important']);
  assert.strictEqual(result.date, new Date('2026-07-08T09:00:00Z').toISOString());
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
