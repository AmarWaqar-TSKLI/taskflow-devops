# scripts

**Owner:** Member 2. Every script: `#!/usr/bin/env bash` + `set -euo pipefail`, passes **ShellCheck**
(checked in CI job `3-lint`), prints usage on bad arguments, exits non-zero on failure.

| Script | Purpose | Called from |
|--------|---------|-------------|
| `build-and-test.sh` | Lint + format check + tests + docker build for both services | Locally before pushing |
| `healthcheck.sh <url>...` | Check URLs with retries/timeouts | `smoke-test.sh`, manual |
| `smoke-test.sh <base_url>` | Post-deploy smoke test: health endpoints + create/read/delete a task | **Pipeline stage 12**, `rollback.yml` |
| `deploy.sh <image_tag>` | Save previous tag, set new tag in SSM, ASG instance refresh, wait | **Pipeline stage 12**, `rollback.yml` |

Test each one for success **and** failure before ticking *Tested*.
