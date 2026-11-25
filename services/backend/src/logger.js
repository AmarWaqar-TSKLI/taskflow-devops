function levelForStatus(status) {
  if (status >= 500) return "error";
  if (status >= 400) return "warn";
  return "info";
}

function createRequestLogger(logFn = console.log) {
  return (req, res, next) => {
    const startNs = process.hrtime.bigint();
    res.on("finish", () => {
      const elapsedMs = Number(process.hrtime.bigint() - startNs) / 1e6;
      logFn(
        JSON.stringify({
          level: levelForStatus(res.statusCode),
          msg: "http request",
          method: req.method,
          path: req.originalUrl || req.url,
          status: res.statusCode,
          duration_ms: Math.round(elapsedMs * 100) / 100,
        }),
      );
    });
    next();
  };
}

module.exports = { createRequestLogger, levelForStatus };
