const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { runInNewContext } = require('node:vm');
const data = {type:'chat_message', tenantId:'afya', appId:'dawapap', recipientUid:'member', registrationId:'registration', generation:'generation'};
const context = JSON.stringify(['afya','dawapap','member']);
function harness(responders = []) {
  let receive;
  const handlers = {}, shown = [], opened = [];
  class Channel {
    constructor() {
      this.port1 = {close() {}, onmessage: null};
      this.port2 = {close() {}, postMessage: data => this.port1.onmessage?.({data})};
    }
  }
  const windows = responders.map(respond => ({postMessage: (message, ports) => ports[0].postMessage(respond(message))}));
  runInNewContext(readFileSync('web/firebase-messaging-sw.js', 'utf8'), {
    importScripts() {}, setTimeout, clearTimeout, MessageChannel: Channel,
    firebase: {initializeApp() {}, messaging: () => ({onBackgroundMessage(fn) {receive = fn;}})},
    console: {log() {throw Error('unexpected logging');}},
    self: {registration: {showNotification(...args) {shown.push(args);}}, addEventListener(name, fn) {handlers[name] = fn;}},
    clients: {matchAll: async () => windows, openWindow: async url => opened.push(url)},
  });
  return {receive, handlers, shown, opened};
}
test('no windows, wrong context, denied validation and unsolicited challenges never display', async () => {
  for (const responders of [[], [() => null], [() => 'wrong'], [m => m.type === 'notification-context' ? context : false], [m => m.type === 'notification-context' ? context : true, () => 'conflicting-tab']]) {
    const h = harness(responders);
    await h.receive({data, notification:{body:'PRIVATE'}});
    await h.receive({data:{type:'notification_possession', proof:'PRIVATE'}});
    assert.equal(h.shown.length, 0);
  }
});
test('matching open windows and backend validation permit only generic display', async () => {
  const h = harness([m => m.type === 'notification-context' ? context : true]);
  await h.receive({data:{...data, body:'PRIVATE', url:'https://untrusted.invalid'}, notification:{body:'PRIVATE'}});
  assert.equal(h.shown.length, 1);
  assert.ok(!JSON.stringify(h.shown).includes('PRIVATE'));
  let pending;
  h.handlers.notificationclick({notification:{close() {}, data:{url:'https://untrusted.invalid'}}, waitUntil(promise) {pending = promise;}});
  await pending;
  assert.deepEqual(h.opened, ['/']);
});
test('context changes during backend validation suppress display', async () => {
  let changed = false;
  const h = harness([m => m.type === 'notification-context' ? (changed ? 'other' : context) : (changed = true)]);
  await h.receive({data});
  assert.equal(h.shown.length, 0);
});
test('registration context checks reject ambiguous tabs', async () => {
  const h = harness([() => context, () => 'other']);
  let pending, allowed;
  h.handlers.message({data:{type:'notification-context-check', context}, ports:[{postMessage(value) {allowed = value;}}], waitUntil(p) {pending = p;}});
  await pending;
  assert.equal(allowed, false);
});
