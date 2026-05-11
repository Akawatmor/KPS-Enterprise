"use client";

import { useState } from "react";
import { login, register } from "../modules/api";

interface AuthFormProps {
  onSuccess: () => void;
  onCancel?: () => void;
}

export default function AuthForm({ onSuccess, onCancel }: AuthFormProps) {
  const [mode, setMode] = useState<"login" | "register">("login");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      if (mode === "register") {
        if (!displayName.trim()) {
          setError("Display name is required");
          setLoading(false);
          return;
        }
        await register(email, password, displayName);
      } else {
        await login(email, password);
      }
      onSuccess();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Authentication failed");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-card">
      <div className="auth-card-header">
        <div>
          <div className="auth-card-kicker">Account</div>
          <h2 className="auth-card-title">
            {mode === "login" ? "Sign in to TodoApp" : "Create your account"}
          </h2>
          <p className="auth-card-copy">
            Use email and password to keep your tasks tied to your own account.
          </p>
        </div>
        {onCancel && (
          <button
            type="button"
            className="btn-secondary"
            onClick={onCancel}
          >
            Close
          </button>
        )}
      </div>

      <form onSubmit={handleSubmit} className="auth-form">
          {mode === "register" && (
            <div className="field-group">
              <label className="field-label">Display name</label>
              <input
                type="text"
                value={displayName}
                onChange={(e) => setDisplayName(e.target.value)}
                className="field-input"
                placeholder="Your name"
                required
              />
            </div>
          )}

          <div className="field-group">
            <label className="field-label">Email</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="field-input"
              placeholder="you@example.com"
              required
            />
          </div>

          <div className="field-group">
            <label className="field-label">Password</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="field-input"
              placeholder="Min 8 chars, include A-Z, a-z, 0-9, symbols"
              required
              minLength={8}
            />
            <div className="auth-card-hint">
              Passwords must be at least 8 characters and include upper, lower,
              number, and symbol.
            </div>
          </div>

          {error && <div className="form-error">{error}</div>}

          <button type="submit" className="btn-primary auth-submit" disabled={loading}>
            {loading ? "Processing..." : mode === "login" ? "Login" : "Register"}
          </button>
        </form>

      <div className="auth-card-toggle">
        {mode === "login" ? (
          <>
            Need an account?{" "}
            <button
              type="button"
              className="auth-inline-link"
              onClick={() => setMode("register")}
            >
              Register
            </button>
          </>
        ) : (
          <>
            Already registered?{" "}
            <button
              type="button"
              className="auth-inline-link"
              onClick={() => setMode("login")}
            >
              Login
            </button>
          </>
        )}
      </div>
    </div>
  );
}
