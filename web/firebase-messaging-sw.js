importScripts("https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyAEW40ijNBdN2aKFRD4cx5p3zVc3AwRXUs",
  authDomain: "mangaka-fc-app.firebaseapp.com",
  projectId: "mangaka-fc-app",
  storageBucket: "mangaka-fc-app.firebasestorage.app",
  messagingSenderId: "255237254114",
  appId: "1:255237254114:web:8d9800f1fa6f78bb0827bb",
  measurementId: "G-HYMVLS4M4J"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notificationTitle = payload.notification?.title || payload.data?.title || "Mangaka FC";
  const notificationOptions = {
    body: payload.notification?.body || payload.data?.body || "New update available",
    icon: "/icons/Icon-192.png",
    data: payload.data || {}
  };
  self.registration.showNotification(notificationTitle, notificationOptions);
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const data = event.notification.data || {};
  let targetUrl = "/";
  if (data.route) {
    targetUrl = data.route;
  } else if (data.mangaId && data.chapterId) {
    targetUrl = `/manga/${data.mangaId}/chapter/${data.chapterId}`;
  } else if (data.mangaId) {
    targetUrl = `/manga/${data.mangaId}`;
  } else if (data.action === "updates") {
    targetUrl = "/updates";
  } else if (data.action === "downloads") {
    targetUrl = "/downloads";
  }
  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((windowClients) => {
      for (const client of windowClients) {
        if ("focus" in client) {
          client.focus();
          return;
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});
