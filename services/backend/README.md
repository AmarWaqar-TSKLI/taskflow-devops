# services/backend

**Code owner:** Member 1 · **Dockerfile owner:** Member 2

Node 24 + Express API. Contract: [docs/ARCHITECTURE.md §3.2–3.3](../../docs/ARCHITECTURE.md#32-http-api-backend-all-under-api).

## Planned layout

```
backend/
├── src/
│   ├── app.js            # builds the Express app (exported — tests import this)
│   ├── server.js         # app.listen(PORT) — the only file that opens a port
│   ├── config.js         # reads env vars (PORT, APP_VERSION, DB_*, LOG_LEVEL)
│   ├── logger.js         # JSON request logging middleware
│   ├── routes/tasks.js   # HTTP layer: parse/validate, call service, map errors
│   ├── services/tasks.js # business rules
│   └── repositories/tasks.js  # SQL via pg — the ONLY layer that touches the DB
├── tests/                # *.test.js — mock repositories, never a real DB
├── jest.config.js        # coverageThreshold 80, lcov reporter
├── eslint.config.js
├── package.json          # scripts: start, test, lint, format:check
├── Dockerfile            # Member 2
└── .dockerignore         # Member 2
```

## Commands

```bash
npm ci
npm test              # jest --coverage
npm run lint
npm run format:check
```

Tests first — see [CONTRIBUTING.md](../../CONTRIBUTING.md#tests-first-tdd).
