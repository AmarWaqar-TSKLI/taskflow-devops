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

> Filled in by Member 2 once `docker-compose.yml` exists (task M2-03).

```bash
docker compose up --build
# frontend: http://localhost:8080   backend: http://localhost:8080/api/health
```

## Deploy from scratch / tear down

> Filled in by Member 4 (task M4-13) — full steps live in [infra/README.md](infra/README.md).

## Links (fill in)

| What | Link |
|------|------|
| GitHub repo | https://github.com/AmarWaqar-TSKLI/taskflow-devops |
| Live app (ALB URL) | `http://<alb-dns-name>` |
| SonarCloud project | |
| Snyk project | |
| CloudWatch dashboard | |
