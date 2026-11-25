const { loadConfig } = require("./config");
const { createPool } = require("./db");
const { createTaskRepository } = require("./repositories/tasks");
const { createApp } = require("./app");

async function initWithRetry(taskRepository, attempts = 5, delayMs = 1000) {
  for (let i = 1; i <= attempts; i += 1) {
    try {
      await taskRepository.initSchema();
      return;
    } catch (err) {
      if (i === attempts) {
        throw err;
      }
      console.error(
        JSON.stringify({
          level: "warn",
          msg: "database not ready yet, retrying schema init",
          attempt: i,
          error: err.message,
        }),
      );
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  }
}

async function start() {
  const config = loadConfig();
  const pool = createPool(config.db);
  const taskRepository = createTaskRepository(pool);

  await initWithRetry(taskRepository);

  const app = createApp({
    appVersion: config.appVersion,
    taskRepository,
  });

  const server = app.listen(config.port, () => {
    console.log(
      JSON.stringify({
        level: "info",
        msg: "backend listening",
        port: config.port,
        version: config.appVersion,
      }),
    );
  });

  const shutdown = () => {
    server.close(() => {
      pool.end().finally(() => process.exit(0));
    });
  };
  process.on("SIGTERM", shutdown);
  process.on("SIGINT", shutdown);
  return server;
}

start().catch((err) => {
  console.error(
    JSON.stringify({
      level: "error",
      msg: "failed to start backend",
      error: err.message,
    }),
  );
  process.exit(1);
});
