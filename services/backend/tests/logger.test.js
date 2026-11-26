const request = require("supertest");
const { createApp } = require("../src/app");
const { createRequestLogger } = require("../src/logger");

describe("JSON request logging middleware", () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it("logs one JSON line per request with level, msg, method, path, status, duration_ms", async () => {
    const entries = [];
    const app = createApp({
      logger: (line) => entries.push(JSON.parse(line)),
    });

    const res = await request(app).get("/api/health");

    expect(res.status).toBe(200);
    expect(entries).toHaveLength(1);
    expect(entries[0]).toEqual({
      level: "info",
      msg: "http request",
      method: "GET",
      path: "/api/health",
      status: 200,
      duration_ms: expect.any(Number),
    });
    expect(entries[0].duration_ms).toBeGreaterThanOrEqual(0);
  });

  it("uses warn for 4xx responses and error for 5xx responses", async () => {
    const entries = [];
    const failingRepo = {
      findAll: jest.fn().mockRejectedValue(new Error("db down")),
    };
    jest.spyOn(console, "error").mockImplementation(() => {});
    const app = createApp({
      taskRepository: failingRepo,
      logger: (line) => entries.push(JSON.parse(line)),
    });

    const notFound = await request(app).get("/api/missing");
    expect(notFound.status).toBe(404);

    const serverErr = await request(app).get("/api/tasks");
    expect(serverErr.status).toBe(500);

    expect(entries[0]).toMatchObject({ level: "warn", status: 404 });
    expect(entries[1]).toMatchObject({ level: "error", status: 500 });
  });

  it("defaults to console.log when no custom logFn is supplied", async () => {
    const logSpy = jest.spyOn(console, "log").mockImplementation(() => {});
    const middleware = createRequestLogger();
    let finishCb;
    const req = {
      method: "GET",
      originalUrl: "/api/health",
      url: "/api/health",
    };
    const res = {
      statusCode: 200,
      on: (event, cb) => {
        if (event === "finish") finishCb = cb;
      },
    };
    const next = jest.fn();

    middleware(req, res, next);
    expect(next).toHaveBeenCalledTimes(1);
    finishCb();

    expect(logSpy).toHaveBeenCalledTimes(1);
    expect(JSON.parse(logSpy.mock.calls[0][0])).toMatchObject({
      level: "info",
      method: "GET",
      path: "/api/health",
      status: 200,
    });
  });
});
