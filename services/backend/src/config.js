function loadConfig(env = process.env) {
  return {
    port: Number(env.PORT) || 3000,
    appVersion: env.APP_VERSION || "dev",
    logLevel: env.LOG_LEVEL || "info",
    db: {
      host: env.DB_HOST || "db",
      port: Number(env.DB_PORT) || 5432,
      database: env.DB_NAME || "taskflow",
      user: env.DB_USER || "taskflow",
      password: env.DB_PASSWORD || "",
    },
  };
}

module.exports = { loadConfig };
