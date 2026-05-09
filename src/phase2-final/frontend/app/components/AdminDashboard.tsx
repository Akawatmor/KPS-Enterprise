"use client";

import { useEffect, useState } from "react";
import { adminListUsers, adminUpdateUserRole, adminDeleteUser, type StoredUser } from "../modules/api";

export default function AdminDashboard() {
  const [users, setUsers] = useState<StoredUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    loadUsers();
  }, []);

  const loadUsers = async () => {
    try {
      const data = await adminListUsers();
      setUsers(data.items || []);
      setError("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load users");
    } finally {
      setLoading(false);
    }
  };

  const handleRoleChange = async (userId: string, newRole: string) => {
    if (!confirm(`Change user role to ${newRole}?`)) return;
    try {
      await adminUpdateUserRole(userId, newRole);
      await loadUsers();
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to update role");
    }
  };

  const handleDeleteUser = async (userId: string) => {
    if (!confirm("Delete this user? This action cannot be undone.")) return;
    try {
      await adminDeleteUser(userId);
      await loadUsers();
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to delete user");
    }
  };

  if (loading) {
    return <div style={styles.loading}>Loading users...</div>;
  }

  if (error) {
    return <div style={styles.error}>Error: {error}</div>;
  }

  return (
    <div style={styles.container}>
      <h2 style={styles.title}>Admin Dashboard — User Management</h2>
      <p style={styles.subtitle}>Total users: {users.length}</p>

      <table style={styles.table}>
        <thead>
          <tr style={styles.headerRow}>
            <th style={styles.th}>Email</th>
            <th style={styles.th}>Display Name</th>
            <th style={styles.th}>Role</th>
            <th style={styles.th}>Actions</th>
          </tr>
        </thead>
        <tbody>
          {users.map((user) => (
            <tr key={user.id} style={styles.row}>
              <td style={styles.td}>{user.email || "—"}</td>
              <td style={styles.td}>{user.display_name || user.username || "—"}</td>
              <td style={styles.td}>
                <span style={user.role === "admin" ? styles.adminBadge : styles.userBadge}>
                  {user.role || "user"}
                </span>
              </td>
              <td style={styles.td}>
                <button
                  onClick={() => handleRoleChange(user.id, user.role === "admin" ? "user" : "admin")}
                  style={styles.roleButton}
                >
                  {user.role === "admin" ? "Demote" : "Promote"}
                </button>
                <button
                  onClick={() => handleDeleteUser(user.id)}
                  style={styles.deleteButton}
                >
                  Delete
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    padding: "2rem",
    maxWidth: "1200px",
    margin: "0 auto",
  },
  title: {
    fontSize: "1.75rem",
    fontWeight: "700",
    color: "#333",
    marginBottom: "0.5rem",
  },
  subtitle: {
    fontSize: "1rem",
    color: "#666",
    marginBottom: "2rem",
  },
  table: {
    width: "100%",
    borderCollapse: "collapse",
    background: "white",
    borderRadius: "8px",
    overflow: "hidden",
    boxShadow: "0 2px 8px rgba(0,0,0,0.1)",
  },
  headerRow: {
    background: "#667eea",
    color: "white",
  },
  th: {
    padding: "1rem",
    textAlign: "left" as const,
    fontWeight: "600",
  },
  row: {
    borderBottom: "1px solid #eee",
  },
  td: {
    padding: "1rem",
    color: "#333",
  },
  adminBadge: {
    display: "inline-block",
    padding: "0.25rem 0.75rem",
    background: "#fbbf24",
    color: "#92400e",
    borderRadius: "12px",
    fontSize: "0.875rem",
    fontWeight: "600",
  },
  userBadge: {
    display: "inline-block",
    padding: "0.25rem 0.75rem",
    background: "#d1d5db",
    color: "#374151",
    borderRadius: "12px",
    fontSize: "0.875rem",
    fontWeight: "600",
  },
  roleButton: {
    marginRight: "0.5rem",
    padding: "0.5rem 1rem",
    background: "#667eea",
    color: "white",
    border: "none",
    borderRadius: "6px",
    cursor: "pointer",
    fontSize: "0.875rem",
    fontWeight: "500",
  },
  deleteButton: {
    padding: "0.5rem 1rem",
    background: "#ef4444",
    color: "white",
    border: "none",
    borderRadius: "6px",
    cursor: "pointer",
    fontSize: "0.875rem",
    fontWeight: "500",
  },
  loading: {
    padding: "2rem",
    textAlign: "center" as const,
    fontSize: "1.25rem",
    color: "#666",
  },
  error: {
    padding: "2rem",
    textAlign: "center" as const,
    color: "#c33",
    fontSize: "1.25rem",
  },
};
