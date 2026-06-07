importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

firebase.initializeApp({
    apiKey: "AIzaSyCSLit2hno644A-S2GoHUMqARTkH1lpfCw",
    authDomain: "pawscare-3b14d.firebaseapp.com",
    projectId: "pawscare-3b14d",
    storageBucket: "pawscare-3b14d.firebasestorage.app",
    messagingSenderId: "189274994253",
    appId: "1:189274994253:web:080777d0cb3bc8b94a4e04",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
    const notificationTitle =
        payload.notification?.title || "Paws & Care";

    const notificationOptions = {
        body: payload.notification?.body || "",
        icon: "/icons/Icon-192.png",
    };

    self.registration.showNotification(
        notificationTitle,
        notificationOptions,
    );
});