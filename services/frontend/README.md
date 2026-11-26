# services/frontend

**Code owner:** Member 1 · **Dockerfile + nginx.conf owner:** Member 2

Static HTML + vanilla JS, bundled with esbuild, served by `nginx-unprivileged` on port **8080**.

- `GET /health` → `200 ok` (served by nginx itself)
- The UI always calls the **relative** path `/api/...`:
  - locally nginx proxies `/api/` to `http://backend:3000`
  - on AWS the ALB routes `/api/*` to the backend target group

## Planned layout

```
frontend/
├── index.html
├── src/
│   ├── api.js        # fetch wrapper for /api/tasks — unit tested with mocked fetch
│   ├── render.js     # pure DOM rendering functions — tested with jsdom
│   └── main.js       # wires it together
├── tests/
├── nginx.conf        # Member 2
├── Dockerfile        # Member 2 (build stage → nginx-unprivileged)
├── .dockerignore     # Member 2
└── package.json      # scripts: build, test, lint, format:check
```
