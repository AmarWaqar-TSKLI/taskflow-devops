module.exports = {
  testEnvironment: "jsdom",
  collectCoverageFrom: ["src/**/*.js", "!src/main.js"],
  coverageDirectory: "coverage",
  coverageReporters: ["text", "lcov"],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80,
    },
  },
};
