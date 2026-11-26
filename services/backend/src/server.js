const { loadConfig } = require("./config");
const { createApp } = require("./app");

function start() {
  const config = loadConfig();
  const app = createApp({ appVersion: config.appVersion });
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
    server.close(() => process.exit(0));
  };
  process.on("SIGTERM", shutdown);
  process.on("SIGINT", shutdown);
  return server;
}

start();
