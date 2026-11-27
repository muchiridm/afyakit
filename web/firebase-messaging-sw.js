// web/firebase-messaging-sw.js

importScripts(
  "https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js",
);

importScripts(
  "https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js",
);

firebase.initializeApp({
  apiKey: "AIzaSyCPTwyhIRqfouFIrcMEQgt8GZBMfLSmxSU",
  authDomain: "afyakit-api.firebaseapp.com",
  projectId: "afyakit-api",
  storageBucket: "afyakit-api.firebasestorage.app",
  messagingSenderId: "484902349205",
  appId: "1:484902349205:web:a778f1abf46525cb7b6e9c",
});

const messaging = firebase.messaging();

// Only currently open, agreeing application windows may authorize display.
function askWindow(client, message) {
  return new Promise((resolve) => {
    const channel = new MessageChannel();
    const finish = (value) => { clearTimeout(timer); channel.port1.close(); resolve(value); };
    const timer = setTimeout(() => finish(null), 2000);
    channel.port1.onmessage = (event) => finish(event.data);
    try { client.postMessage(message, [channel.port2]); } catch (_) { finish(null); }
  });
}
async function agreeingWindows(context) {
  const windows = await clients.matchAll({ type: 'window', includeUncontrolled: true });
  if (!windows.length || typeof context !== 'string') return [];
  const contexts = await Promise.all(windows.map(client => askWindow(client, { type: 'notification-context' })));
  return contexts.every(value => value === context) ? windows : [];
}
self.addEventListener('message', (event) => {
  if (event.data?.type !== 'notification-context-check' || !event.ports?.length) return;
  event.waitUntil((async () => {
    const windows = await agreeingWindows(event.data.context);
    event.ports[0].postMessage(windows.length > 0);
  })());
});
messaging.onBackgroundMessage(async (payload) => {
  const data = payload.data;
  if (!data || !['chat_message', 'activity'].includes(data.type) ||
      !['tenantId', 'appId', 'recipientUid', 'registrationId', 'generation'].every(key => typeof data[key] === 'string' && data[key])) return;
  const context = JSON.stringify([data.tenantId, data.appId, data.recipientUid]);
  const windows = await agreeingWindows(context);
  if (!windows.length) return;
  const allowed = await Promise.all(windows.map(client => askWindow(client, { type: 'notification-validate', payload: {
    type: data.type, tenantId: data.tenantId, appId: data.appId, recipientUid: data.recipientUid,
    registrationId: data.registrationId, generation: data.generation,
  } })));
  if (!allowed.some(value => value === true)) return;
  // Recheck context after asynchronous backend validation.
  if (!(await agreeingWindows(context)).length) return;
  await self.registration.showNotification('AfyaKit', {
    body: data.type === 'chat_message' ? 'You have a new message.' : 'You have a new update.',
    tag: 'afyakit-update',
  });
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  // Never follow a push-supplied URL or expose a stale resource outside auth.
  event.waitUntil(clients.openWindow("/"));
});
