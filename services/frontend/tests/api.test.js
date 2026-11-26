const {
  fetchHealth,
  listTasks,
  createTask,
  updateTask,
  deleteTask,
} = require("../src/api");

describe("TaskFlow API client", () => {
  afterEach(() => {
    delete global.fetch;
  });

  it("fetchHealth returns parsed JSON when /api/health responds ok", async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ status: "ok", service: "backend", version: "dev" }),
    });

    const data = await fetchHealth();

    expect(global.fetch).toHaveBeenCalledWith("/api/health");
    expect(data).toEqual({ status: "ok", service: "backend", version: "dev" });
  });

  it("fetchHealth throws when response is not ok", async () => {
    const mockFetch = jest.fn().mockResolvedValue({ ok: false, status: 503 });
    await expect(fetchHealth(mockFetch)).rejects.toThrow(
      "Health check failed with status 503",
    );
  });

  it("listTasks fetches /api/tasks", async () => {
    const sample = [{ id: 1, title: "Test", done: false }];
    const mockFetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => sample,
    });

    const tasks = await listTasks(mockFetch);

    expect(mockFetch).toHaveBeenCalledWith("/api/tasks");
    expect(tasks).toEqual(sample);
  });

  it("createTask sends POST /api/tasks with JSON title", async () => {
    const created = { id: 2, title: "Ship UI", done: false };
    const mockFetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => created,
    });

    const result = await createTask("Ship UI", mockFetch);

    expect(mockFetch).toHaveBeenCalledWith("/api/tasks", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: "Ship UI" }),
    });
    expect(result).toEqual(created);
  });

  it("updateTask sends PATCH /api/tasks/:id", async () => {
    const updated = { id: 2, title: "Ship UI", done: true };
    const mockFetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => updated,
    });

    const result = await updateTask(2, { done: true }, mockFetch);

    expect(mockFetch).toHaveBeenCalledWith("/api/tasks/2", {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ done: true }),
    });
    expect(result).toEqual(updated);
  });

  it("deleteTask sends DELETE /api/tasks/:id", async () => {
    const mockFetch = jest.fn().mockResolvedValue({
      ok: true,
      status: 204,
    });

    await deleteTask(2, mockFetch);

    expect(mockFetch).toHaveBeenCalledWith("/api/tasks/2", {
      method: "DELETE",
    });
  });

  it("extracts server error message on 4xx/5xx JSON responses", async () => {
    const mockFetch = jest.fn().mockResolvedValue({
      ok: false,
      status: 400,
      json: async () => ({ error: "title must be a string" }),
    });

    await expect(createTask("", mockFetch)).rejects.toThrow(
      "title must be a string",
    );
  });

  it("falls back to status code message when error body is not JSON", async () => {
    const mockFetch = jest.fn().mockResolvedValue({
      ok: false,
      status: 502,
      json: async () => {
        throw new Error("invalid json");
      },
    });

    await expect(listTasks(mockFetch)).rejects.toThrow(
      "Request failed with status 502",
    );
  });
});
