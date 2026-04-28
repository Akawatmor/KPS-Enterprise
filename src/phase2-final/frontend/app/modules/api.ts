// app/modules/api.ts
// Empty string → relative paths (same-domain via Traefik ingress in K3s).
// Set NEXT_PUBLIC_API_BASE_URL at build time only for cross-origin setups.

export const API_BASE: string = process.env.NEXT_PUBLIC_API_BASE_URL ?? "";

// ── Domain Types ──────────────────────────────────────────────────────────────
export interface StoredUser {
  id: string;
  username: string;
  email?: string;
}

interface AuthExchangeResponse {
  session?: { access_token: string };
  user?: StoredUser;
}

// ── Token / User storage ──────────────────────────────────────────────────────
export function getStoredToken(): string | null {
  if (typeof window === "undefined") return null;
  return localStorage.getItem("todoapp.access_token");
}

export function setStoredToken(token: string | null): void {
  if (typeof window === "undefined") return;
  if (token) localStorage.setItem("todoapp.access_token", token);
  else localStorage.removeItem("todoapp.access_token");
}

export function getStoredUser(): StoredUser | null {
  if (typeof window === "undefined") return null;
  try {
    return JSON.parse(localStorage.getItem("todoapp.user") || "null") as StoredUser | null;
  } catch {
    return null;
  }
}

export function setStoredUser(user: StoredUser | null): void {
  if (typeof window === "undefined") return;
  if (user) localStorage.setItem("todoapp.user", JSON.stringify(user));
  else localStorage.removeItem("todoapp.user");
}

// ── HTTP helpers ──────────────────────────────────────────────────────────────
function buildURL(endpoint: string): string {
  const path = endpoint.startsWith("/api/v1")
    ? endpoint
    : `/api/v1${endpoint.startsWith("/") ? endpoint : `/${endpoint}`}`;
  return `${API_BASE}${path}`;
}

export async function fetchAPI<T = unknown>(
  endpoint: string,
  options: RequestInit = {}
): Promise<T> {
  const token = getStoredToken();
  const authHeader: Record<string, string> = token
    ? { Authorization: `Bearer ${token}` }
    : { "X-User-ID": "local-dev-user" };

  const res = await fetch(buildURL(endpoint), {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...authHeader,
      ...(options.headers as Record<string, string>),
    },
  });

  if (res.status === 401) {
    setStoredToken(null);
    setStoredUser(null);
    throw new Error("Unauthorized");
  }
  if (!res.ok) {
    const text = await res.text();
    throw new Error(text || `HTTP ${res.status}`);
  }
  return res.json() as Promise<T>;
}

export async function loginGitHub(code = "demo-code"): Promise<AuthExchangeResponse> {
  const data = await fetchAPI<AuthExchangeResponse>("/auth/github/exchange", {
    method: "POST",
    body: JSON.stringify({ code }),
  });
  if (data?.session?.access_token) setStoredToken(data.session.access_token);
  if (data?.user) setStoredUser(data.user);
  return data;
}

export function logout(): void {
  setStoredToken(null);
  setStoredUser(null);
}
