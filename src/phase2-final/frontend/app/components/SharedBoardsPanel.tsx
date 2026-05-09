"use client";

import { useEffect, useState } from "react";
import { listUserBoards, createSharedBoard, type SharedBoard } from "../modules/api";

export default function SharedBoardsPanel() {
  const [boards, setBoards] = useState<SharedBoard[]>([]);
  const [boardName, setBoardName] = useState("");
  const [boardDesc, setBoardDesc] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [showCreate, setShowCreate] = useState(false);

  useEffect(() => {
    loadBoards();
  }, []);

  const loadBoards = async () => {
    try {
      const data = await listUserBoards();
      setBoards(data.items || []);
      setError("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load boards");
    } finally {
      setLoading(false);
    }
  };

  const handleCreateBoard = async () => {
    if (!boardName.trim()) return;
    try {
      await createSharedBoard(boardName, boardDesc);
      setBoardName("");
      setBoardDesc("");
      setShowCreate(false);
      await loadBoards();
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to create board");
    }
  };

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <h2 style={styles.title}>Shared Kanban Boards</h2>
        <button onClick={() => setShowCreate(!showCreate)} style={styles.createButton}>
          {showCreate ? "Cancel" : "+ New Board"}
        </button>
      </div>

      {showCreate && (
        <div style={styles.createForm}>
          <input
            type="text"
            value={boardName}
            onChange={(e) => setBoardName(e.target.value)}
            placeholder="Board name"
            style={styles.input}
          />
          <textarea
            value={boardDesc}
            onChange={(e) => setBoardDesc(e.target.value)}
            placeholder="Description (optional)"
            style={styles.textarea}
            rows={3}
          />
          <button onClick={handleCreateBoard} style={styles.button}>
            Create Board
          </button>
        </div>
      )}

      {loading && <p>Loading boards...</p>}
      {error && <p style={styles.error}>{error}</p>}

      <div style={styles.boardsList}>
        {boards.length === 0 && !loading && (
          <p style={styles.empty}>No shared boards yet. Create one!</p>
        )}
        {boards.map((board) => (
          <div key={board.id} style={styles.boardCard}>
            <h3 style={styles.boardName}>{board.name}</h3>
            {board.description && (
              <p style={styles.boardDesc}>{board.description}</p>
            )}
            <p style={styles.boardMeta}>Created {new Date(board.created_at).toLocaleDateString()}</p>
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
  header: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: "1.5rem",
  },
  title: {
    fontSize: "1.5rem",
    fontWeight: "700",
    color: "#333",
    margin: 0,
  },
  createButton: {
    padding: "0.625rem 1.25rem",
    background: "#10b981",
    color: "white",
    border: "none",
    borderRadius: "6px",
    cursor: "pointer",
    fontWeight: "600",
  },
  createForm: {
    padding: "1.5rem",
    background: "#f9fafb",
    borderRadius: "8px",
    marginBottom: "1.5rem",
    display: "flex",
    flexDirection: "column",
    gap: "0.75rem",
  },
  input: {
    padding: "0.75rem",
    border: "1px solid #ddd",
    borderRadius: "6px",
    fontSize: "1rem",
  },
  textarea: {
    padding: "0.75rem",
    border: "1px solid #ddd",
    borderRadius: "6px",
    fontSize: "1rem",
    fontFamily: "inherit",
  },
  button: {
    padding: "0.75rem",
    background: "#667eea",
    color: "white",
    border: "none",
    borderRadius: "6px",
    cursor: "pointer",
    fontWeight: "600",
  },
  boardsList: {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fill, minmax(280px, 1fr))",
    gap: "1rem",
  },
  boardCard: {
    padding: "1.25rem",
    background: "#fafbfc",
    border: "1px solid #e5e7eb",
    borderRadius: "8px",
    transition: "box-shadow 0.2s",
    cursor: "pointer",
  },
  boardName: {
    fontSize: "1.125rem",
    fontWeight: "600",
    color: "#333",
    margin: "0 0 0.5rem 0",
  },
  boardDesc: {
    fontSize: "0.875rem",
    color: "#666",
    margin: "0 0 0.75rem 0",
  },
  boardMeta: {
    fontSize: "0.75rem",
    color: "#999",
    margin: 0,
  },
  empty: {
    gridColumn: "1 / -1",
    textAlign: "center",
    color: "#999",
    padding: "2rem",
  },
  error: {
    color: "#c33",
    marginBottom: "1rem",
  },
};
