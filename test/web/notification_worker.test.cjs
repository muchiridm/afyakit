const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { runInNewContext } = require('node:vm');
test('worker neither logs/displays background payloads nor navigates to push-supplied URLs', async () => {
  let receive, click;
  const opened = [];
  runInNewContext(readFileSync('web/firebase-messaging-sw.js', 'utf8'), {
    importScripts() {}, firebase: { initializeApp() {}, messaging: () => ({ onBackgroundMessage(fn) { receive = fn; } }) },
    console: { log() { throw Error('unexpected logging'); } },
    self: { registration: { showNotification() { throw Error('unexpected display'); } }, addEventListener(name, fn) { click = fn; } },
    clients: { openWindow(url) { opened.push(url); return Promise.resolve(); } },
  });
  receive({ notification: { body: 'PRIVATE' }, data: { url: 'https://untrusted.invalid' } });
  let pending;
  click({ notification: { close() {}, data: { url: 'https://untrusted.invalid' } }, waitUntil(promise) { pending = promise; } });
  await pending;
  assert.deepEqual(opened, ['/']);
});
