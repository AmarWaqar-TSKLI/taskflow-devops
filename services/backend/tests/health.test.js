const request = require("supertest");
const { createApp } = require("../src/app");

describe("GET /api/health", () => {
  it("returns ok status, service name, and default version without querying a database", async () => {
    const app = createApp();
    const res = await request(app).get("/api/health");

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      status: "ok",
      service: "backend",
      version: "dev",
    });
  });

  it("returns configured appVersion when provided", async () => {
    const app = createApp({ appVersion: "v1.0.42" });
    const res = await request(app).get("/api/health");

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      status: "ok",
      service: "backend",
      version: "v1.0.42",
    });
  });
});
