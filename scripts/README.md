# scripts

**Owner:** Member 2. Every script: `#!/usr/bin/env bash` + `set -euo pipefail`, passes **ShellCheck**
(checked in CI job `3-lint`), prints usage on bad arguments, exits non-zero on failure.

| Script                                                | Purpose                                                                 | Called from                           |
| ----------------------------------------------------- | ----------------------------------------------------------------------- | ------------------------------------- |
| `build-and-test.sh [--no-docker] [backend\|frontend]` | Lint + format check + tests + build + `docker build` for both services  | Locally before pushing                |
| `healthcheck.sh [-r n] [-d s] [-t s] <url>...`        | Check URLs answer 2xx, with retries and timeouts                        | `smoke-test.sh`, manual               |
| `smoke-test.sh <base_url>`                            | Post-deploy smoke test: health endpoints, UI, create/read/delete a task | **Pipeline stage 12**, `rollback.yml` |
| `deploy.sh <image_tag>`                               | Save previous tag, set new tag in SSM, ASG instance refresh, wait       | **Pipeline stage 12**, `rollback.yml` |

Exit codes are the same everywhere: `0` passed · `1` a check failed · `2` bad usage or a missing tool.

```bash
scripts/build-and-test.sh                     # what CI stages 3, 4, 6, 9 will run, before you push
scripts/healthcheck.sh http://localhost:8080/health http://localhost:8080/api/health
scripts/smoke-test.sh http://localhost:8080   # against the local Compose stack
EXPECT_VERSION=v1.0.42 scripts/smoke-test.sh "$ALB_URL"   # also checks the live version
```

Tuning (env): `HEALTHCHECK_RETRIES` (10), `HEALTHCHECK_DELAY` (3 s), `HEALTHCHECK_TIMEOUT` (5 s) for
`healthcheck.sh` and `smoke-test.sh`; `EXPECT_VERSION` for `smoke-test.sh`.

`smoke-test.sh` needs `curl` and `jq` (both on GitHub runners). It deletes its test task even if a later
check fails.

Test each one for success **and** failure before ticking _Tested_.
