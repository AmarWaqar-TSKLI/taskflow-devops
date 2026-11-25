const { Pool } = require("pg");
const awsSslProfiles = require("aws-ssl-profiles");

function buildPoolOptions(dbConfig) {
  const useRdsTls =
    dbConfig.ssl === true ||
    (typeof dbConfig.host === "string" &&
      dbConfig.host.endsWith(".rds.amazonaws.com"));

  const ssl = useRdsTls
    ? {
        rejectUnauthorized: true,
        ca: awsSslProfiles.ca,
      }
    : false;

  return {
    host: dbConfig.host,
    port: dbConfig.port,
    database: dbConfig.database,
    user: dbConfig.user,
    password: dbConfig.password,
    ssl,
    max: 10,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 5000,
  };
}

function createPool(dbConfig) {
  return new Pool(buildPoolOptions(dbConfig));
}

module.exports = { buildPoolOptions, createPool };
