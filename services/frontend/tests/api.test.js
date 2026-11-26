const { fetchHealth } = require("../src/api");

describe("fetchHealth", () => {
  afterEach(() => {
    delete global.fetch;
  });

  it("returns parsed JSON when /api/health responds ok", async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ status: "ok", service: "backend", version: "dev" }),
    });

    const data = await fetchHealth();

    expect(global.fetch).toHaveBeenCalledWith("/api/health");
    expect(data).toEqual({ status: "ok", service: "backend", version: "dev" });
  });

  it("throws an error when /api/health responds non-ok", async () => {
    const mockFetch = jest.fn().mockResolvedValue({
      ok: false,
      status: 503,
    });

    await expect(fetchHealth(mockFetch)).rejects.toThrow(
      "Health check failed with status 503",
    );
  });
});
