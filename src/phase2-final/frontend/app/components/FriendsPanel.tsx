"use client";

import { useEffect, useState } from "react";
import { listFriends, sendFriendRequest, type StoredUser } from "../modules/api";

export default function FriendsPanel() {
  const [friends, setFriends] = useState<StoredUser[]>([]);
  const [friendEmail, setFriendEmail] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    loadFriends();
  }, []);

  const loadFriends = async () => {
    try {
      const data = await listFriends();
      setFriends(data.items || []);
      setError("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load friends");
    } finally {
      setLoading(false);
    }
  };

  const handleAddFriend = async () => {
    if (!friendEmail.trim()) return;
    try {
      await sendFriendRequest(friendEmail);
      setFriendEmail("");
      alert("Friend request sent!");
      await loadFriends();
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to send request");
    }
  };

  return (
    <div style={styles.container}>
      <h2 style={styles.title}>Friends</h2>

      <div style={styles.addSection}>
        <input
          type="text"
          value={friendEmail}
          onChange={(e) => setFriendEmail(e.target.value)}
          placeholder="Enter friend's user ID"
          style={styles.input}
        />
        <button onClick={handleAddFriend} style={styles.button}>
          Add Friend
        </button>
      </div>

      {loading && <p>Loading...</p>}
      {error && <p style={styles.error}>{error}</p>}

      <div style={styles.friendsList}>
        {friends.length === 0 && !loading && (
          <p style={styles.empty}>No friends yet. Add some!</p>
        )}
        {friends.map((friend) => (
          <div key={friend.id} style={styles.friendCard}>
            <div>
              <div style={styles.friendName}>
                {friend.display_name || friend.username}
              </div>
              <div style={styles.friendEmail}>{friend.email}</div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    padding: "1.5rem",
    background: "white",
    borderRadius: "8px",
    boxShadow: "0 2px 8px rgba(0,0,0,0.1)",
  },
  title: {
    fontSize: "1.5rem",
    fontWeight: "700",
    marginBottom: "1.5rem",
    color: "#333",
  },
  addSection: {
    display: "flex",
    gap: "0.5rem",
    marginBottom: "1.5rem",
  },
  input: {
    flex: 1,
    padding: "0.75rem",
    border: "1px solid #ddd",
    borderRadius: "6px",
    fontSize: "1rem",
  },
  button: {
    padding: "0.75rem 1.5rem",
    background: "#667eea",
    color: "white",
    border: "none",
    borderRadius: "6px",
    cursor: "pointer",
    fontWeight: "600",
  },
  friendsList: {
    display: "flex",
    flexDirection: "column",
    gap: "0.75rem",
  },
  friendCard: {
    padding: "1rem",
    background: "#f9fafb",
    borderRadius: "6px",
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
  },
  friendName: {
    fontWeight: "600",
    color: "#333",
  },
  friendEmail: {
    fontSize: "0.875rem",
    color: "#666",
  },
  empty: {
    textAlign: "center",
    color: "#999",
    padding: "2rem",
  },
  error: {
    color: "#c33",
    marginBottom: "1rem",
  },
};
