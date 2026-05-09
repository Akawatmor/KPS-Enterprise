"use client";

import { useEffect, useState } from "react";
import { savePushSubscription } from "../modules/api";

export default function PWAInstaller() {
  const [supported, setSupported] = useState(false);
  const [subscribed, setSubscribed] = useState(false);

  useEffect(() => {
    if ("serviceWorker" in navigator && "PushManager" in window) {
      setSupported(true);
      registerServiceWorker();
      checkSubscription();
    }
  }, []);

  const registerServiceWorker = async () => {
    try {
      const registration = await navigator.serviceWorker.register("/sw.js");
      console.log("Service Worker registered:", registration);
    } catch (error) {
      console.error("Service Worker registration failed:", error);
    }
  };

  const checkSubscription = async () => {
    try {
      const registration = await navigator.serviceWorker.ready;
      const subscription = await registration.pushManager.getSubscription();
      setSubscribed(!!subscription);
    } catch (error) {
      console.error("Failed to check subscription:", error);
    }
  };

  const subscribeToPush = async () => {
    try {
      const permission = await Notification.requestPermission();
      if (permission !== "granted") {
        alert("Notification permission denied");
        return;
      }

      const registration = await navigator.serviceWorker.ready;
      
      // You need to generate VAPID keys and replace this
      const vapidPublicKey = "YOUR_VAPID_PUBLIC_KEY";
      
      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(vapidPublicKey),
      });

      await savePushSubscription(subscription);
      setSubscribed(true);
      alert("Push notifications enabled!");
    } catch (error) {
      console.error("Push subscription failed:", error);
      alert("Failed to enable push notifications");
    }
  };

  const unsubscribeFromPush = async () => {
    try {
      const registration = await navigator.serviceWorker.ready;
      const subscription = await registration.pushManager.getSubscription();
      if (subscription) {
        await subscription.unsubscribe();
        setSubscribed(false);
        alert("Push notifications disabled");
      }
    } catch (error) {
      console.error("Unsubscribe failed:", error);
    }
  };

  if (!supported) {
    return null;
  }

  return (
    <div style={styles.container}>
      <div style={styles.card}>
        <h3 style={styles.title}>📱 Push Notifications</h3>
        <p style={styles.description}>
          Get notified about upcoming tasks and reminders
        </p>
        {subscribed ? (
          <button onClick={unsubscribeFromPush} style={styles.buttonDisable}>
            Disable Notifications
          </button>
        ) : (
          <button onClick={subscribeToPush} style={styles.button}>
            Enable Notifications
          </button>
        )}
      </div>
    </div>
  );
}

// Helper to convert VAPID key
function urlBase64ToUint8Array(base64String: string): Uint8Array {
  const padding = "=".repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/");
  const rawData = window.atob(base64);
  const outputArray = new Uint8Array(rawData.length);
  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i);
  }
  return outputArray;
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    padding: "1rem",
  },
  card: {
    background: "white",
    borderRadius: "8px",
    boxShadow: "0 2px 8px rgba(0,0,0,0.1)",
    padding: "1.5rem",
  },
  title: {
    fontSize: "1.25rem",
    fontWeight: "700",
    margin: "0 0 0.5rem 0",
    color: "#333",
  },
  description: {
    fontSize: "0.875rem",
    color: "#666",
    margin: "0 0 1rem 0",
  },
  button: {
    padding: "0.75rem 1.5rem",
    background: "#10b981",
    color: "white",
    border: "none",
    borderRadius: "6px",
    cursor: "pointer",
    fontWeight: "600",
    width: "100%",
  },
  buttonDisable: {
    padding: "0.75rem 1.5rem",
    background: "#ef4444",
    color: "white",
    border: "none",
    borderRadius: "6px",
    cursor: "pointer",
    fontWeight: "600",
    width: "100%",
  },
};
