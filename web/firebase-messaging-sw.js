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

// N1: Web background pushes are data-only and carry no content. A service
// worker cannot establish the current authenticated recipient. Suppress display
// until N2 defines the secure installation/session lifecycle. Foreground Flutter
// validates tenant, application, recipient and membership before generic display.
messaging.onBackgroundMessage(() => undefined);

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  // Never follow a push-supplied URL or expose a stale resource outside auth.
  event.waitUntil(clients.openWindow("/"));
});
