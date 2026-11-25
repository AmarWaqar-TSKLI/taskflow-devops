const express = require("express");
const { loadConfig } = require("./config");

function createApp(options = {}) {
  const config = loadConfig();
  const appVersion = options.appVersion ?? config.appVersion;

  const app = express();
  app.disable("x-powered-by");
  app.use(express.json({ limit: "16kb" }));

  // Liveness probe only: must never query Postgres (ARCHITECTURE §3.2).
  app.get("/api/health", (_req, res) => {
    res.status(200).json({
      status: "ok",
      service: "backend",
      version: appVersion,
    });
  });

  return app;
}

module.exports = { createApp };
