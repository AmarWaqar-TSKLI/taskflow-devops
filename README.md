# TaskFlow — DevOps Final Project

A small task-tracker app (frontend + backend API + Postgres) deployed on AWS through a full
12-stage DevSecOps pipeline. **The app is deliberately tiny — we are graded on the DevOps and
security around it.**

> **Deadline: Monday 30 November 2026.** Internal feature freeze: **Saturday 28 November, 23:59.**

---

## Start here (read in this order)

| # | File | What it tells you | Time |
|---|------|-------------------|------|
| 1 | [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md) | Everything the brief demands, as a checklist. **You never need to open the .docx.** | 10 min |
| 2 | [docs/WORK.md](docs/WORK.md) | Who owns what (Members 1–4), your tasks, due dates, "done when" | 10 min |
| 3 | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | How the system fits together + **the contracts** (ports, names, env vars) everyone must use | 15 min |
| 4 | [CONTRIBUTING.md](CONTRIBUTING.md) | How we work: tests first, branches, PRs, reviews, secrets | 10 min |
| 5 | [docs/PROGRESS.md](docs/PROGRESS.md) | The tracker. Tick **Built** and **Tested** as you go | — |

## Repository layout

```
.
├── README.md                  ← you are here
├── CONTRIBUTING.md            ← team rules (TDD, branches, PRs, secrets)
├── SECURITY.md                ← (Member 3) scanners, thresholds, accepted findings
├── VERSION                    ← major.minor of the app, e.g. 1.0 → images tagged v1.0.<run>
├── docker-compose.yml         ← (Member 2) local stack, one command
├── docker-compose.prod.yml    ← (Member 2) stack on EC2, images from ECR
│
├── services/
│   ├── backend/               ← (Member 1) Node/Express API + Jest tests + Dockerfile (Member 2)
│   └── frontend/              ← (Member 1) static UI + Jest tests + Dockerfile (Member 2)
│
├── scripts/                   ← (Member 2) shell scripts: build-and-test, healthcheck, deploy, smoke-test
├── infra/                     ← (Member 4) AWS setup docs, IAM policies, user-data
│   └── iam/                   ← JSON trust + permission policies for every role
├── monitoring/                ← (Member 1) CloudWatch agent config, dashboard JSON, alarms
├── loadtest/                  ← (Member 1) k6 load test
├── .github/
│   ├── workflows/             ← pipeline.yml (stages 1–12), rollback.yml
│   ├── dependabot.yml         ← (Member 3)
│   └── pull_request_template.md
│
└── docs/
    ├── REQUIREMENTS.md        ← the brief, as a checklist
    ├── WORK.md                ← work division
    ├── PROGRESS.md            ← tracker
    ├── ARCHITECTURE.md        ← design + contracts
    ├── brief/                 ← original brief (.docx) + pipeline image
    ├── evidence/              ← screenshots for the PDF (naming rules inside)
    ├── incidents/             ← post-incident notes
    └── submission/            ← diagram, findings report, GroupX.pdf
```

Every folder has its own `README.md` saying who owns it and what goes in it.

## Run locally

Needs Docker with the Compose plugin (Docker Desktop is fine). Nothing else: Node, npm and Postgres all
run inside containers.

```bash
cp .env.example .env        # once: local-only DB password (git-ignored)
docker compose up --build   # builds both images, starts db -> backend -> frontend
```

| What | URL |
|------|-----|
| App | http://localhost:8080 |
| Frontend health | http://localhost:8080/health |
| Backend health (through nginx) | http://localhost:8080/api/health |

- Only port 8080 is published. nginx in `frontend` proxies `/api/` to `backend:3000` on the Compose
  network `taskflow`; `backend` talks to `db:5432`. The database is not reachable from the host.
- Startup order is enforced with health checks: `backend` waits for Postgres, `frontend` waits for the
  backend's `/api/health`.
- Both app containers run as non-root, read-only, with all Linux capabilities dropped.
- Useful: `docker compose logs -f backend` (JSON request logs) · `docker compose down` (stop) ·
  `docker compose down -v` (stop and wipe the local database).

## Network design

All AWS infrastructure lives in `us-east-1`, in one VPC spread over two Availability Zones.

| Subnet | CIDR | AZ | Routes to the internet via | What runs there |
|--------|------|----|----------------------------|-----------------|
| `taskflow-public-a` | `10.0.1.0/24` | us-east-1a | Internet gateway | ALB node, NAT gateway |
| `taskflow-public-b` | `10.0.2.0/24` | us-east-1b | Internet gateway | ALB node |
| `taskflow-private-a` | `10.0.11.0/24` | us-east-1a | NAT gateway (outbound only) | App instances (ASG), RDS |
| `taskflow-private-b` | `10.0.12.0/24` | us-east-1b | NAT gateway (outbound only) | App instances (ASG), RDS subnet group |

- **Why public vs private:** only the load balancer and the NAT gateway need to be reachable from or
  routable to the internet. App instances and the database have no public IPs, so nothing on the
  internet can open a connection to them.
- **Why `10.0.0.0/16` and `/24`s:** plenty of room (251 usable IPs per subnet) and simple to read.
- **NAT:** one NAT gateway in AZ a lets private instances pull images from ECR and reach SSM, Secrets
  Manager and CloudWatch. One instead of two saves ~$32/month. The trade-off (AZ a outage blocks new
  image pulls in AZ b) is accepted for a student budget.
- **Security groups, chained by reference:**
  internet → `taskflow-alb-sg` (TCP 80) → `taskflow-app-sg` (TCP 8080, 3000 from the ALB SG only) →
  `taskflow-db-sg` (TCP 5432 from the app SG only). **No port 22 anywhere**; shell access is SSM Session Manager.
- **How services find each other:**
  - *Locally:* Docker Compose network `taskflow`. nginx in `frontend` proxies `/api/` to `http://backend:3000`;
    `backend` connects to `db:5432`.
  - *On AWS:* the ALB routes `/api/*` to the backend target group (port 3000) and everything else to the
    frontend target group (port 8080). The backend reads the RDS endpoint from Secrets Manager
    (`taskflow/prod/db`). The browser only ever calls relative `/api/...`, so the same frontend code works in both.

Full reasoning: [docs/ARCHITECTURE.md §4](docs/ARCHITECTURE.md#4-network-design). Resource IDs and every
setting: [infra/README.md](infra/README.md).

## Deploy from scratch / tear down

Everything in AWS is created by the scripts in [`infra/`](infra/). Each one is safe to re-run (it finds
existing resources by name). Every setting and the reason for it is in [infra/README.md](infra/README.md).

**Prerequisites:** AWS CLI v2 logged in as an admin of the account, region `us-east-1`; `jq`; `gh`
logged in as the repo owner (used to set GitHub variables).

```bash
# 1. Free layer (create once, stays up)
BUDGET_EMAILS="a@x.com,b@y.com" infra/00-budget.sh   # monthly budget + email alerts
infra/00-team-users.sh          # IAM users for teammates (console only, no access keys)
infra/01-network.sh             # VPC, 4 subnets in 2 AZs, internet gateway, route tables
infra/02-security-groups.sh     # alb-sg -> app-sg -> db-sg, no SSH
infra/03-iam.sh                 # GitHub OIDC provider + CI / deploy / EC2 roles
gh variable set AWS_ACCOUNT_ID --body <account-id>
gh variable set AWS_REGION --body us-east-1
infra/04-ssm-params.sh          # /taskflow/prod/image_tag + previous_image_tag
infra/05-launch-template.sh     # taskflow-lt (AL2023, t3.micro, IMDSv2, no key pair) + user-data
infra/06-target-groups.sh       # frontend :8080 /health, backend :3000 /api/health
#    + ECR repos and log groups (see infra/README.md §10-11)

# 2. Paid layer: RDS -> NAT gateway -> ALB (writes ALB_URL) -> ASG
infra/up.sh

# 3. Deploy: merge to main. Stages 11-12 push the images and roll them out.
```

**Pause between work sessions** (not while the project is being graded): `infra/down.sh` scales the
ASG to 0, deletes the ALB and NAT gateway and stops RDS. Nothing is lost; `infra/up.sh` brings it back.

**Tear everything down (only after grading is complete):**

```bash
CONFIRM=delete-taskflow infra/teardown.sh
```

It deletes in dependency order: ASG, launch template, ALB, target groups, RDS, secret, NAT gateway,
VPC (security groups, route tables, subnets, IGW), ECR repos, log groups, SSM parameters, alarms,
dashboard, SNS topic, IAM roles and the OIDC provider. Then check AWS Billing for anything left running.

## Application, Testing & Monitoring (`M1`)

- **Backend ([services/backend/](services/backend/README.md)):** Node + Express API layered as `routes -> service -> repository` (`pg`), auto-creating the `tasks` table on startup and connecting to RDS over verified TLS (`aws-ssl-profiles`). Emits single-line JSON request logs (`level`, `msg`, `method`, `path`, `status`, `duration_ms`) to stdout for CloudWatch `awslogs`.
  - Endpoints: `GET /api/health` (liveness only, returns `APP_VERSION`), `GET/POST/PATCH/DELETE /api/tasks`.
- **Frontend ([services/frontend/](services/frontend/README.md)):** Vanilla JS + static HTML bundled with `esbuild` into `dist/`, calling relative `/api/...` endpoints with XSS-safe DOM rendering.
- **Tests & coverage:** Jest (`supertest` + `jsdom`), ESLint, and Prettier in both services with an enforced **≥ 80%** global coverage threshold and `coverage/lcov.info` output.
- **Load test ([loadtest/](loadtest/README.md)):** `loadtest/load.js` (k6) ramps traffic against `$BASE_URL` to drive ASG CPU past the 50% scale-out threshold and back down for scale-in verification.
- **Monitoring ([monitoring/](monitoring/README.md)):** CloudWatch Agent config (`/taskflow/prod/cloudwatch-agent`), SNS topic `taskflow-alerts`, dashboard `taskflow-dashboard`, and alarms (`taskflow-unhealthy-frontend`, `taskflow-unhealthy-backend`, `taskflow-backend-5xx`, `taskflow-high-cpu`) provisioned via `monitoring/setup-monitoring.sh`.

## Links (fill in)

| What | Link |
|------|------|
| GitHub repo | https://github.com/hussainwaz/taskflow-devops |
| Live app (ALB URL) | http://taskflow-alb-466982077.us-east-1.elb.amazonaws.com |
| SonarCloud project | https://sonarcloud.io/project/overview?id=AmarWaqar-TSKLI_taskflow-devops |
| Snyk | CLI scan in pipeline job `8-dependency-scan` (high/critical fails the build) |
| CloudWatch dashboard | https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards/dashboard/taskflow-dashboard |
