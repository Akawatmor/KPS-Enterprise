// app/modules/api.ts
// Empty string → relative paths (same-domain via Traefik ingress in K3s).
// Set NEXT_PUBLIC_API_BASE_URL at build time only for cross-origin setups.

export const API_BASE: string = process.env.NEXT_PUBLIC_API_BASE_URL ?? "";

// ── Domain Types ──────────────────────────────────────────────────────────────
export interface StoredUser {
  id: string;
  username: string;
  email?: string;
  role?: string; // "user" | "admin"
  display_name?: string;
}

interface AuthExchangeResponse {
  session?: { access_token: string };
  user?: StoredUser;
}

interface SessionBundle {
  user: StoredUser;
  session: { access_token: string; refresh_token?: string };
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

// ── Password Authentication ───────────────────────────────────────────────────

export async function register(email: string, password: string, displayName: string): Promise<SessionBundle> {
  const data = await fetchAPI<SessionBundle>("/auth/register", {
    method: "POST",
    body: JSON.stringify({ email, password, display_name: displayName }),
  });
  if (data?.session?.access_token) setStoredToken(data.session.access_token);
  if (data?.user) setStoredUser(data.user);
  return data;
}

export async function login(email: string, password: string): Promise<SessionBundle> {
  const data = await fetchAPI<SessionBundle>("/auth/login", {
    method: "POST",
    body: JSON.stringify({ email, password }),
  });
  if (data?.session?.access_token) setStoredToken(data.session.access_token);
  if (data?.user) setStoredUser(data.user);
  return data;
}

export function logout(): void {
  const token = getStoredToken();
  if (token) {
    fetchAPI("/auth/session/logout", {
      method: "POST",
      body: JSON.stringify({ access_token: token }),
    }).catch(() => {});
  }
  setStoredToken(null);
  setStoredUser(null);
}

// ── Admin API ─────────────────────────────────────────────────────────────────

export async function adminListUsers(): Promise<{ items: StoredUser[] }> {
  return fetchAPI<{ items: StoredUser[] }>("/admin/users");
}

export async function adminUpdateUserRole(userId: string, role: string): Promise<StoredUser> {
  return fetchAPI<StoredUser>(`/admin/users/${userId}/role`, {
    method: "PATCH",
    body: JSON.stringify({ role }),
  });
}

export async function adminDeleteUser(userId: string): Promise<void> {
  await fetchAPI(`/admin/users/${userId}`, { method: "DELETE" });
}

// ── Friends API ───────────────────────────────────────────────────────────────

export async function sendFriendRequest(friendId: string): Promise<unknown> {
  return fetchAPI("/friends/request", {
    method: "POST",
    body: JSON.stringify({ friend_id: friendId }),
  });
}

export async function acceptFriendRequest(friendshipId: string): Promise<unknown> {
  return fetchAPI(`/friends/${friendshipId}/accept`, { method: "POST" });
}

export async function listFriends(): Promise<{ items: StoredUser[] }> {
  return fetchAPI<{ items: StoredUser[] }>("/friends");
}

// ── Shared Boards API ─────────────────────────────────────────────────────────

export interface SharedBoard {
  id: string;
  name: string;
  description: string;
  owner_id: string;
  created_at: string;
}

export async function createSharedBoard(name: string, description: string): Promise<SharedBoard> {
  return fetchAPI<SharedBoard>("/boards", {
    method: "POST",
    body: JSON.stringify({ name, description }),
  });
}

export async function listUserBoards(): Promise<{ items: SharedBoard[] }> {
  return fetchAPI<{ items: SharedBoard[] }>("/boards");
}

export async function addBoardMember(boardId: string, userId: string, role: string): Promise<unknown> {
  return fetchAPI(`/boards/${boardId}/members`, {
    method: "POST",
    body: JSON.stringify({ user_id: userId, role }),
  });
}

// ── Push Notifications API ────────────────────────────────────────────────────

export async function savePushSubscription(subscription: PushSubscription): Promise<void> {
  const json = subscription.toJSON();
  await fetchAPI("/push/subscribe", {
    method: "POST",
    body: JSON.stringify({
      endpoint: subscription.endpoint,
      p256dh: json.keys?.p256dh || "",
      auth: json.keys?.auth || "",
    }),
  });
}
