# Work division — Members 1 to 5

Each member **owns** an area end-to-end (builds it, tests it, documents it, takes its screenshots, and can
explain it in the viva). Owning doesn't mean working alone. Pair up whenever a task says "with Mx".

Task IDs here match [PROGRESS.md](PROGRESS.md) and go in your branch names and commits.

## Team

| Member | Name | Roll no. | GitHub | Area |
|--------|------|----------|--------|------|
| **M1** | | | @ | Application & tests & load test |
| **M2** | | | @ | Containers, shell scripts, CD (deploy + rollback) |
| **M3** | | | @ | CI pipeline & DevSecOps |
| **M4** | | | @ | AWS infrastructure, IAM & networking |
| **M5** | | | @ | Observability, incident, diagram, report & final PDF |

Group number (for `GroupX.pdf`): **____**

## Timeline

| Phase | Dates | Goal at the end of the phase |
|-------|-------|------------------------------|
| **P0 Setup** | Mon 16 – Tue 17 Nov | Everyone has cloned, installed tools and read the docs; M3 and M4 accounts/tokens ready |
| **P1 Foundations** | Wed 18 – Sun 22 Nov | App works in Compose · CI stages 2–10 green · VPC, IAM/OIDC, RDS, ECR exist |
| **P2 Cloud & CD** | Mon 23 – Thu 26 Nov | Live on ALB · merge to main auto-deploys · auto-rollback works · dashboard + alarms live |
| **P3 Demos & evidence** | Fri 27 – Sat 28 Nov | All demos run and screenshotted. **Feature freeze Sat 28, 23:59** |
| **P4 Submission** | Sun 29 – Mon 30 Nov | Diagram, report, README, `GroupX.pdf` submitted. Only fixes, nothing new |

## Who depends on whom

```
M1 app ──► M2 Dockerfiles ──► M3 jobs 5, 9, 10      M4 VPC/IAM/ECR/RDS ──► M2 jobs 11–12
   │                              │                       │
   └── JSON request logs ──► M5 dashboard/alarms ◄── M4 ALB/ASG
```

- The **critical path** is **M4 → M2 (CD)**. If M4 slips, CD slips, and so do all the demos. Others should help M4 first.
- Until M1's app is ready, M2 and M3 build against a "hello world" Express app + static page (M1-01/M1-02 land on day 2).

---

## Every member, on your own (P0, by Tue 17 Nov)

Each person does these for themselves.

| ID | Task | Done when |
|----|------|-----------|
| T-01 | Fill in your row of the Team table above (name, roll no., GitHub) | Your row is complete |
| T-02 | Install: Git, Docker, Node 24, AWS CLI v2, ShellCheck, (optional) `gh`, k6 | `docker run hello-world` works |
| T-03 | Read README → REQUIREMENTS → WORK → ARCHITECTURE → CONTRIBUTING | You can explain the 12 stages without looking |

---

## Member 1 — Application, tests & load test

**Owns:** `services/backend/`, `services/frontend/` (code, not Dockerfiles), `loadtest/`.
**Viva focus:** the app, tests and coverage, TDD, the load test.

| ID | Task | Due | Done when |
|----|------|-----|-----------|
| M1-01 | Backend skeleton: Express `app.js` (exported) + `server.js` (listen), `GET /api/health`, Jest + supertest, ESLint + Prettier configs, `npm test / lint / format:check` scripts. **Health test written first.** | Tue 17 | `npm test` passes; health returns contract JSON |
| M1-02 | Frontend skeleton: `index.html` + `src/` JS modules, esbuild build to `dist/`, Jest (jsdom), ESLint, Prettier | Wed 18 | `npm run build` produces `dist/`; a test passes |
| M1-03 | Tasks API (GET/POST/PATCH/DELETE) per contract, layered routes → service → repository. Tests first, repository mocked, 400/404 cases covered | Fri 20 | All endpoints tested, incl. errors |
| M1-04 | Postgres repository with `pg`, config from env vars (contract §3.3), `CREATE TABLE IF NOT EXISTS` on startup | Fri 20 | Works against Compose `db` |
| M1-05 | Frontend UI: list / add / toggle / delete tasks via relative `/api/...`; tests for the API client + rendering | Sat 21 | Works at `localhost:8080` in Compose |
| M1-06 | Coverage ≥ 80% enforced via `coverageThreshold`; `lcov` output at `coverage/lcov.info` for Sonar | Sat 21 | CI fails if coverage drops |
| M1-07 | JSON request logging middleware (`method, path, status, duration_ms`) — feeds M5's logs | Sun 22 | Log lines visible in `docker compose logs backend` |
| M1-08 | `APP_VERSION` in health response (so we can *see* which version is live) | Sun 22 | Health shows version on AWS |
| M1-09 | `loadtest/load.js` k6 script: ramp up to drive CPU > target, hold, ramp down. `loadtest/README.md` how to run | Wed 25 | Script runs against ALB |
| M1-10 | Help M5: app section of README + lessons learned for the report | Sun 29 | Text handed to M5 |

## Member 2 — Containers, shell scripts & CD

**Owns:** both `Dockerfile`s + `.dockerignore`s, `docker-compose.yml`, `docker-compose.prod.yml`, `scripts/`,
jobs `11-push-image` + `12-deploy` in `pipeline.yml`, `rollback.yml`, ECR repos.
**Viva focus:** Docker best practices, compose, how a merge becomes a running container, rollback.

| ID | Task | Due | Done when |
|----|------|-----|-----------|
| M2-01 | Backend Dockerfile: multi-stage (`npm ci` → prod deps only), pinned base (`node:24.x.y-alpine3.yy` or distroless), `USER` non-root, `HEALTHCHECK`, `.dockerignore` | Wed 18 | Hadolint clean; `docker run --rm img id` ≠ root |
| M2-02 | Frontend Dockerfile: build stage (node, esbuild) → `nginxinc/nginx-unprivileged:<pinned>` on 8080; `nginx.conf` with `/health` and `/api/` proxy to `backend:3000` | Wed 18 | Hadolint clean; `/health` → 200 |
| M2-03 | `docker-compose.yml` (frontend, backend, db with volume + healthcheck, network `taskflow`, `.env.example`). One command: `docker compose up --build`. Write the "Run locally" section of README | Thu 19 | Fresh clone → app works |
| M2-04 | `scripts/build-and-test.sh`: lint + format check + tests + docker build for both services | Fri 20 | ShellCheck clean; fails correctly if a test fails |
| M2-05 | `scripts/healthcheck.sh <url>...`: checks each URL with retries/timeouts, non-zero exit on failure | Fri 20 | ShellCheck clean; tested up and down |
| M2-06 | `scripts/smoke-test.sh <base_url>`: frontend `/health`, `/api/health`, create a task, read it back, delete it. **This is stage 12's smoke test** | Sat 21 | Passes vs local Compose; fails when backend stopped |
| M2-07 | ECR repos `taskflow-frontend` / `taskflow-backend`: **tag immutability ON**, scan on push, lifecycle policy (keep last 20) | Sat 21 | Console screenshot |
| M2-08 | `docker-compose.prod.yml`: images `<acct>.dkr.ecr.us-east-1.amazonaws.com/taskflow-*:${IMAGE_TAG}`, `env_file` from the secret file, `awslogs` driver (log groups from contract), `restart: always`, no `db` service (RDS) | Sun 22 | Works on an EC2 test instance (with M4) |
| M2-09 | Job `11-push-image`: OIDC → `taskflow-github-ci-role`, load artifacts from job 9, tag with SHA + `v<VERSION>.<run_number>`, push | Mon 23 | Both tags visible in ECR after a merge |
| M2-10 | `scripts/deploy.sh <tag>`: save previous tag, set `/taskflow/prod/image_tag`, start instance refresh, wait until done | Tue 24 | ShellCheck clean; refresh completes |
| M2-11 | Job `12-deploy`: OIDC → deploy role → `deploy.sh` → `smoke-test.sh $ALB_URL` → on failure `deploy.sh <previous>` and fail the job | Wed 25 | A bad build is rolled back automatically |
| M2-12 | `.github/workflows/rollback.yml`: `workflow_dispatch` input `image_tag`, verify tag exists in ECR, deploy + smoke test | Thu 26 | Rolled back to an older tag successfully |

## Member 3 — CI pipeline & DevSecOps

**Owns:** `.github/workflows/pipeline.yml` jobs 2–10, branch protection, SonarCloud, Snyk, Dependabot,
`SECURITY.md`, PR template, the viva walkthrough.
**Viva focus:** every pipeline stage, why each tool exists, how a vulnerable change gets blocked.

| ID | Task | Due | Done when |
|----|------|-----|-----------|
| M3-00 | Protect `main` right after the scaffold is pushed (no direct push, PR + 1 approval; CI checks added in M3-10). Create SonarCloud org + project and Snyk account; add `SONAR_TOKEN`, `SNYK_TOKEN` to GitHub Secrets | Tue 17 | Direct push rejected; secrets listed in repo settings |
| M3-01 | `pipeline.yml` skeleton: triggers `push` + `pull_request`, jobs 2→10 chained with `needs:`, exact job names from ARCHITECTURE §5 | Wed 18 | Visible chain in the Actions UI |
| M3-02 | `2-secret-scan`: Gitleaks with `fetch-depth: 0` (full history) | Wed 18 | Green on main |
| M3-03 | `3-lint` (ESLint both services + ShellCheck on `scripts/` and `infra/*.sh`) and `4-format` (Prettier `--check`) | Thu 19 | Fails on a deliberately bad file |
| M3-04 | `5-dockerfile-lint`: Hadolint on both Dockerfiles | Thu 19 | Green |
| M3-05 | `6-unit-tests`: Jest with coverage for both services, upload coverage artifact | Fri 20 | Coverage artifact downloadable |
| M3-06 | `7-static-analysis`: SonarCloud scan + **wait for quality gate** (fails job if gate fails); `sonar-project.properties` | Fri 20 | Gate result shown in PR |
| M3-07 | `8-dependency-scan`: Snyk `--severity-threshold=high` both services; `.github/dependabot.yml` (npm ×2, docker ×2, github-actions; weekly) | Sat 21 | Snyk green; Dependabot PRs appear |
| M3-08 | `9-build-image`: build both images, `docker save` → upload artifact (job 11 pushes these exact images) | Sat 21 | Artifact present |
| M3-09 | `10-image-scan`: Trivy on both images, `--severity HIGH,CRITICAL --exit-code 1` | Sat 21 | Green on main |
| M3-10 | Branch protection: require PR + 1 approval, **all 9 jobs (2–10) as required checks**, dismiss stale approvals, no force-push, include admins | Sun 22 | Screenshot of settings |
| M3-11 | `SECURITY.md`: tools + thresholds per stage, how secrets are handled, table of accepted findings with reasons, how to report | Sun 22 (keep updated) | Linked from README |
| M3-12 | `.github/pull_request_template.md` review checklist (already scaffolded — adjust if needed) + optional `CODEOWNERS` | Wed 18 | Template appears on new PRs |
| M3-13 | `docs/VIVA.md`: step-by-step script any member can follow live to push a change and show a security stage blocking it | Sat 28 | Every member has rehearsed it once |

## Member 4 — AWS infrastructure, IAM & networking

**Owns:** everything in the AWS account except monitoring, `infra/` (README, `iam/*.json`, `user-data.sh`).
**Viva focus:** VPC design, security groups, IAM/OIDC, ASG + ALB, how instances boot.

> Document every setting in `infra/README.md` **as you create it** (values + why). Rebuilding from the
> README must be possible — that's a graded requirement.

| ID | Task | Due | Done when |
|----|------|-----|-----------|
| M4-00 | AWS account setup: Budget alert (e.g. $20/month, emails to all), IAM user + MFA for each member, region `us-east-1` | Tue 17 | Everyone can log in; budget alert email confirmed |
| M4-01 | VPC `10.0.0.0/16`, 2 public + 2 private subnets (contract §4), IGW, 1 NAT gateway, public & private route tables | Thu 19 | Subnets in 2 AZs; documented |
| M4-02 | Security groups `alb-sg`, `app-sg`, `db-sg` exactly as ARCHITECTURE §4. No port 22 | Thu 19 | Rules documented + screenshot |
| M4-03 | GitHub OIDC identity provider + `taskflow-github-ci-role` + `taskflow-github-deploy-role`, trust limited to our repo's `main`. JSON in `infra/iam/` | Fri 20 | Test workflow assumes role (`aws sts get-caller-identity`) |
| M4-04 | `taskflow-ec2-role` + instance profile (ECR read, SSM core, CW agent, secret + param read) | Fri 20 | JSON in `infra/iam/` |
| M4-05 | RDS Postgres 17 `db.t4g.micro`, private subnets, `db-sg`, **password managed in Secrets Manager `taskflow/prod/db`**, no public access | Sat 21 | Reachable only from app-sg |
| M4-06 | SSM parameters `/taskflow/prod/image_tag` + `/taskflow/prod/previous_image_tag` | Sat 21 | Exist |
| M4-07 | `infra/user-data.sh` (with M2): install Docker + compose plugin + CW agent, ECR login, read tag + secret, write root-only env file, `compose up -d` | Sun 22 | ShellCheck clean; test instance serves app |
| M4-08 | Launch template `taskflow-lt`: Amazon Linux 2023, `t3.micro`, no key pair, **IMDSv2 required**, ec2 role, `app-sg`, user-data | Sun 22 | Documented |
| M4-09 | ALB `taskflow-alb` in public subnets, target groups (contract §3.5) with health checks, listener rule `/api/*` → backend, default → frontend | Mon 23 | Both TGs healthy |
| M4-10 | ASG `taskflow-asg`: private subnets ×2, min 2 / desired 2 / max 4, ELB health checks, grace 180 s, **target tracking CPU 50%** (or request count per target) | Mon 23 | 2 healthy instances in 2 AZs |
| M4-11 | Verify SSM Session Manager into an instance; confirm SSH impossible | Mon 23 | Screenshot |
| M4-12 | Live link working: put ALB URL in README + GitHub variable `ALB_URL` | Mon 23 | URL opens the app |
| M4-13 | `infra/README.md` complete: every setting, rebuild from scratch, **teardown order**, cost notes | Sat 28 | A teammate could rebuild from it |
| M4-14 | Cost control: scale down overnight while testing, **restore before demos and keep everything up until grading** | ongoing | Budget not exceeded |

## Member 5 — Observability, incident, diagram, report & PDF

**Owns:** `monitoring/`, CloudWatch (logs, dashboard, alarms, SNS), `docs/incidents/`, `docs/submission/`,
final README polish, and assembling `GroupX.pdf`.
**Viva focus:** what each metric/alarm means, how the incident was diagnosed, the architecture diagram.

| ID | Task | Due | Done when |
|----|------|-----|-----------|
| M5-01 | Start the architecture diagram now (draw.io / Excalidraw), keep updating as things get built | Wed 18 (draft) | Draft shared |
| M5-02 | Log groups `/taskflow/frontend`, `/taskflow/backend`, 7-day retention (with M2 for the `awslogs` driver) | Sun 22 | Logs from EC2 visible |
| M5-03 | `monitoring/cloudwatch-agent.json` for memory (`mem_used_percent`) + disk, by ASG name; installed via user-data (with M4) | Mon 23 | Memory metric visible |
| M5-04 | SNS topic `taskflow-alerts`, email subscriptions for all members (everyone confirms) | Mon 23 | Test message received |
| M5-05 | Dashboard `taskflow-dashboard`: request rate, 5xx errors, latency p50/p95/p99, healthy hosts, CPU, memory. Export to `monitoring/dashboard.json` | Tue 24 | Screenshot |
| M5-06 | Alarms (contract §8): unhealthy hosts, backend 5xx, optional CPU. Export definitions to `monitoring/alarms.md` | Tue 24 | Each alarm tested once |
| M5-07 | Write the post-incident note after the team runs D-07: `docs/incidents/2026-11-27-<name>.md` (template in that folder) | Sat 28 | Written |
| M5-08 | Final architecture diagram meeting every point in REQUIREMENTS "Part 1" → `docs/submission/architecture.png` | Sat 28 | Reviewed by M4 |
| M5-09 | One-page findings report + contribution table (`docs/submission/report.md`), input from everyone | Sun 29 | Everyone approved their row |
| M5-10 | README final: run locally (from M2), deploy from scratch + teardown (from M4), links table filled | Sun 29 | Links clickable |
| M5-11 | Assemble `GroupX.pdf` (cover page with names + roll nos., diagram, proof + screenshots, live link, report). Final link check | Mon 30 AM | **Submitted** |

---

## Demos & evidence — whole team, together (P3, Fri 27 – Sat 28)

Demos are **not owned by anyone**. The whole team runs them together on one call, and a different person
drives each one. That way everyone has done every demo once before the viva (any of us can be asked to show
any of them).

Run them in this order. The incident goes last because it breaks things on purpose. Screenshot names are in
[evidence/README.md](evidence/README.md).

| ID | Demo | What to show |
|----|------|--------------|
| D-01 | CI pipeline | A run with jobs 2–10 as separate green jobs |
| D-02 | Security gate | PR adding a known-vulnerable dependency → Snyk/Trivy fails → merge blocked. Close the PR, don't merge |
| D-03 | Failure recovery | Traffic running → terminate an instance → app stays up → ASG launches a replacement |
| D-04 | Scaling | k6 load test → scale-out → load stops → scale-in (CloudWatch CPU + ASG activity history) |
| D-05 | Delivery | Commit merged → auto-deployed (version changes in `/api/health`) → manual rollback to an older tag |
| D-06 | Setup proof | Multi-AZ subnets + instances, OIDC trust policy, ECR tags, branch protection |
| D-07 | Incident | Deliberate failure (suggested: remove the `app-sg` rule from `db-sg`) → backend 5xx → alarm + SNS email → diagnose from logs/metrics → restore rule → recovery. Note the times for the post-incident note |
