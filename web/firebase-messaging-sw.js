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

messaging.onBackgroundMessage((message) => {
  console.log("🔔 Firebase background message:", message);

  const data = message.data || {};
  const notification = message.notification || {};

  const title = notification.title || data.title || "DawaPap";

  const body = notification.body || data.body || "You have a new message.";

  const options = {
    body,
    icon: "/icons/Icon-192.png",
    badge: "/icons/Icon-192.png",
    data: {
      ...data,
      url: data.url || "/",
    },
  };

  return self.registration.showNotification(title, options);
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();

  const url = event.notification.data?.url || "/";

  event.waitUntil(
    clients
      .matchAll({
        type: "window",
        includeUncontrolled: true,
      })
      .then((windowClients) => {
        for (const client of windowClients) {
          if ("focus" in client) {
            client.focus();

            if ("navigate" in client) {
              return client.navigate(url);
            }

            return client;
          }
        }

        if (clients.openWindow) {
          return clients.openWindow(url);
        }

        return null;
      }),
  );
});
