const request = require("supertest");
const { createApp } = require("../src/app");

describe("GET /api/health", () => {
  const originalVersion = process.env.APP_VERSION;

  afterEach(() => {
    if (originalVersion === undefined) {
      delete process.env.APP_VERSION;
    } else {
      process.env.APP_VERSION = originalVersion;
    }
  });

  it("returns ok status, service name, and default version without querying a database", async () => {
    delete process.env.APP_VERSION;
    const app = createApp({ logger: () => {} });
    const res = await request(app).get("/api/health");

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      status: "ok",
      service: "backend",
      version: "dev",
    });
  });

  it("reads APP_VERSION from environment when present", async () => {
    process.env.APP_VERSION = "v1.0.77";
    const app = createApp({ logger: () => {} });
    const res = await request(app).get("/api/health");

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      status: "ok",
      service: "backend",
      version: "v1.0.77",
    });
  });

  it("returns configured appVersion option when provided", async () => {
    const app = createApp({ appVersion: "v1.0.42", logger: () => {} });
    const res = await request(app).get("/api/health");

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      status: "ok",
      service: "backend",
      version: "v1.0.42",
    });
  });
});
