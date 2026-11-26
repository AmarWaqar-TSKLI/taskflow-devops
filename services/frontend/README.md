# services/frontend

**Code owner:** Member 1 · **Dockerfile + nginx.conf owner:** Member 2

Static HTML + vanilla JS, bundled with esbuild (`npm run build` → `dist/`), served by `nginx-unprivileged` on port **8080**.

- `GET /health` → `200 ok` (served by nginx itself)
- The UI always calls the **relative** path `/api/...`:
  - locally nginx proxies `/api/` to `http://backend:3000`
  - on AWS the ALB routes `/api/*` to the backend target group

## Layout

```text
frontend/
├── index.html
├── styles.css
├── build.js          # esbuild bundle + copies index.html/styles.css into dist/
├── src/
│   ├── api.js        # fetch wrapper for /api/tasks (unit tested with mocked fetch)
│   ├── render.js     # XSS-safe DOM rendering functions (tested with jsdom)
│   └── main.js       # wires form, toggle, delete, and initial load
├── tests/
├── jest.config.js
├── eslint.config.js
└── package.json      # scripts: build, test, lint, format:check
```

## Commands

```bash
npm ci
npm run build         # outputs dist/index.html, dist/styles.css, dist/bundle.js
npm test              # jest --coverage
npm run lint
npm run format:check
```
