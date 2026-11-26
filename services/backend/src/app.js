const express = require("express");
const { loadConfig } = require("./config");
const { AppError } = require("./errors");
const { createRequestLogger } = require("./logger");
const { createTaskService } = require("./services/tasks");
const { createTasksRouter } = require("./routes/tasks");

function createApp(options = {}) {
  const config = loadConfig();
  const appVersion = options.appVersion ?? config.appVersion;
  const service =
    options.taskService ||
    (options.taskRepository ? createTaskService(options.taskRepository) : null);

  const app = express();
  app.disable("x-powered-by");
  app.use(createRequestLogger(options.logger));
  app.use(express.json({ limit: "16kb" }));

  // Liveness probe only: must never query Postgres (ARCHITECTURE §3.2).
  app.get("/api/health", (_req, res) => {
    res.status(200).json({
      status: "ok",
      service: "backend",
      version: appVersion,
    });
  });

  if (service) {
    app.use("/api/tasks", createTasksRouter(service));
  }

  app.use((_req, res) => {
    res.status(404).json({ error: "not found" });
  });

  app.use((err, _req, res, _next) => {
    if (err instanceof SyntaxError && err.status === 400 && "body" in err) {
      return res.status(400).json({ error: "invalid JSON body" });
    }
    if (err instanceof AppError) {
      return res.status(err.status).json({ error: err.message });
    }
    console.error(
      JSON.stringify({
        level: "error",
        msg: "unhandled error",
        error: err.message,
      }),
    );
    return res.status(500).json({ error: "internal server error" });
  });

  return app;
}

module.exports = { createApp };
