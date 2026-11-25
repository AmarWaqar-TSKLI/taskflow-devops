module.exports = {
  testEnvironment: "jsdom",
  collectCoverageFrom: ["src/**/*.js", "!src/main.js"],
  coverageDirectory: "coverage",
  coverageReporters: ["text", "lcov"],
};
