# services/backend

**Code owner:** Member 1 · **Dockerfile owner:** Member 2

Node 24 + Express API backed by PostgreSQL (`pg`). Contract:
[docs/ARCHITECTURE.md §3.2–3.3](../../docs/ARCHITECTURE.md#32-http-api-backend-all-under-api).

## Layout

```text
backend/
├── src/
│   ├── app.js               # builds the Express app (exported for supertest)
│   ├── server.js            # initializes schema + app.listen(PORT)
│   ├── config.js            # reads env vars (PORT, APP_VERSION, DB_*, LOG_LEVEL)
│   ├── db.js                # pg.Pool configuration (auto-TLS for *.rds.amazonaws.com)
│   ├── errors.js            # ValidationError (400), NotFoundError (404)
│   ├── certs/               # public AWS RDS us-east-1 CA bundle
│   ├── routes/tasks.js      # HTTP layer: /api/tasks CRUD
│   ├── services/tasks.js    # validation and business rules
│   └── repositories/tasks.js # parameterized SQL via pg + startup table creation
├── tests/                   # *.test.js — repository/pool mocked in unit tests
├── jest.config.js
├── eslint.config.js
└── package.json             # scripts: start, test, lint, format:check
```

## Endpoints

- `GET /api/health` → `200 {"status":"ok","service":"backend","version":"<APP_VERSION>"}` (no DB query)
- `GET /api/tasks` → `200 [{id, title, done, created_at}]`
- `POST /api/tasks` (`{"title": "1–200 chars"}`) → `201 {task}` or `400 {"error": "..."}`
- `PATCH /api/tasks/:id` (`{"title"?, "done"?}`) → `200 {task}` or `400`/`404`
- `DELETE /api/tasks/:id` → `204` or `400`/`404`

## Commands

```bash
npm ci
npm test              # jest --coverage
npm run lint
npm run format:check
```

Tests first — see [CONTRIBUTING.md](../../CONTRIBUTING.md#tests-first-tdd).
