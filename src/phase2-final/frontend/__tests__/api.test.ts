import {
  getStoredToken,
  setStoredToken,
  getStoredUser,
  setStoredUser,
  logout,
  fetchAPI,
  API_BASE,
} from "../app/modules/api";

// ── Token storage ─────────────────────────────────────────────────────────────
describe("Token storage", () => {
  beforeEach(() => localStorage.clear());

  it("returns null when no token is stored", () => {
    expect(getStoredToken()).toBeNull();
  });

  it("stores and retrieves a token", () => {
    setStoredToken("my-secret-token");
    expect(getStoredToken()).toBe("my-secret-token");
  });

  it("removes the token when null is passed", () => {
    setStoredToken("existing-token");
    setStoredToken(null);
    expect(getStoredToken()).toBeNull();
  });
});

// ── User storage ──────────────────────────────────────────────────────────────
describe("User storage", () => {
  beforeEach(() => localStorage.clear());

  it("returns null when no user is stored", () => {
    expect(getStoredUser()).toBeNull();
  });

  it("stores and retrieves a user object", () => {
    setStoredUser({ id: "u1", username: "alice", email: "alice@example.com" });
    expect(getStoredUser()).toEqual({
      id: "u1",
      username: "alice",
      email: "alice@example.com",
    });
  });

  it("removes the user when null is passed", () => {
    setStoredUser({ id: "u1", username: "alice" });
    setStoredUser(null);
    expect(getStoredUser()).toBeNull();
  });

  it("returns null for corrupted JSON in localStorage", () => {
    localStorage.setItem("todoapp.user", "{ invalid json");
    expect(getStoredUser()).toBeNull();
  });
});

// ── logout ────────────────────────────────────────────────────────────────────
describe("logout", () => {
  beforeEach(() => localStorage.clear());

  it("clears both token and user", () => {
    setStoredToken("tok-123");
    setStoredUser({ id: "u1", username: "alice" });
    logout();
    expect(getStoredToken()).toBeNull();
    expect(getStoredUser()).toBeNull();
  });
});

// ── fetchAPI ──────────────────────────────────────────────────────────────────
describe("fetchAPI", () => {
  beforeEach(() => {
    localStorage.clear();
    global.fetch = jest.fn();
  });

  afterEach(() => jest.restoreAllMocks());

  it("sends X-User-ID header when no token is stored", async () => {
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: async () => ({ items: [] }),
    });

    await fetchAPI("/tasks");

    expect(global.fetch).toHaveBeenCalledWith(
      `${API_BASE}/api/v1/tasks`,
      expect.objectContaining({
        headers: expect.objectContaining({ "X-User-ID": "local-dev-user" }),
      }),
    );
  });

  it("sends Authorization Bearer header when a token is stored", async () => {
    setStoredToken("bearer-token");
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: async () => ({}),
    });

    await fetchAPI("/tasks");

    expect(global.fetch).toHaveBeenCalledWith(
      `${API_BASE}/api/v1/tasks`,
      expect.objectContaining({
        headers: expect.objectContaining({ Authorization: "Bearer bearer-token" }),
      }),
    );
  });

  it("prepends /api/v1 to bare paths", async () => {
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: async () => ({}),
    });

    await fetchAPI("tasks");

    expect(global.fetch).toHaveBeenCalledWith(
      `${API_BASE}/api/v1/tasks`,
      expect.anything(),
    );
  });

  it("does not double-prefix already-prefixed paths", async () => {
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: async () => ({}),
    });

    await fetchAPI("/api/v1/tasks");

    expect(global.fetch).toHaveBeenCalledWith(
      `${API_BASE}/api/v1/tasks`,
      expect.anything(),
    );
  });

  it("throws the response body text on non-OK responses", async () => {
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: false,
      status: 500,
      text: async () => "Internal Server Error",
    });

    await expect(fetchAPI("/tasks")).rejects.toThrow("Internal Server Error");
  });

  it("throws 'HTTP 500' when response body is empty", async () => {
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: false,
      status: 500,
      text: async () => "",
    });

    await expect(fetchAPI("/tasks")).rejects.toThrow("HTTP 500");
  });

  it("clears the stored token and throws Unauthorized on 401", async () => {
    setStoredToken("expired-token");
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: false,
      status: 401,
      text: async () => "",
    });

    await expect(fetchAPI("/tasks")).rejects.toThrow("Unauthorized");
    expect(getStoredToken()).toBeNull();
  });
});
