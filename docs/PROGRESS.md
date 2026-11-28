# Progress tracker

**How to use**
- Change `⬜` to `✅` in **Built** when the PR is merged, and in **Tested** when the proof exists.
- Put the PR number and/or proof link in **Proof** (CI run URL, screenshot path, or "see PR #12").
- Tick your rows **in the same PR as the work** (see [CONTRIBUTING.md](../CONTRIBUTING.md#definition-of-done-both-columns-in-progressmd)).
- Blocked? Put `🚧 <reason>` in Proof and say so in the group chat.
- Task details and "done when" criteria: [WORK.md](WORK.md).

## Summary (update at each standup)

| Area | Owner | Done / total |
|------|-------|--------------|
| Member setup | Each member | 3 / 3 |
| App, tests & monitoring | M1 | 12 / 14 |
| Containers, scripts, CD & PDF | M2 | 14 / 15 |
| CI, DevSecOps, diagram & report | M3 | 12 / 16 |
| AWS infra & incident note | M4 | 15 / 16 |
| Demos | Whole team | 6 / 7 |
| Submission | Whole team | 8 / 12 |

---

## Status 28 Nov — what's left

- **Live:** http://taskflow-alb-466982077.us-east-1.elb.amazonaws.com, auto-deployed on every push to main. Paid AWS layer stays **up until grading**.
- **PDF:** `node docs/submission/build-pdf.mjs` → `docs/submission/23L-3035_23L-3018_23L-3069_23L-3024.pdf` (we have no group number). All links checked OK. **One gap:** `D06-01-branch-protection.png`.
- **Branch protection (M3-10, D-06):** Hussain (repo admin) turns it on: Settings → Branches → rule for `main`, require PR + 1 approval, required checks `2-secret-scan` … `10-image-scan`. Amar takes the screenshot → `docs/evidence/D06-01-branch-protection.png`, plus PR #22 showing "merge blocked" → `D02-02-merge-blocked.png`. Then rebuild the PDF and submit it.
- **SNS:** confirmation emails re-sent 28 Nov to Shuja (l233024) and Hussain (l233018): click "Confirm subscription".
- Close PR #22 after the merge-blocked screenshot (never merge it).

## Member setup — each member, by Tue 17 Nov

Tick your own initials when done.

| ID | Task | M1 | M2 | M3 | M4 |
|----|------|----|----|----|----|
| T-01 | Your row in the Team table filled | ✅ | ✅ | ✅ | ✅ |
| T-02 | Tools installed | ✅ | ✅ | ✅ | ✅ |
| T-03 | Docs read | ✅ | ✅ | ✅ | ✅ |

## Member 1 — Application, tests, load test & monitoring

| ID | Task | Due | Built | Tested | Proof |
|----|------|-----|-------|--------|-------|
| M1-01 | Backend skeleton + `/api/health` + Jest/ESLint/Prettier | 17 Nov | ✅ | ✅ | `npm test` (2/2 health tests, 100% cov), `npm run lint`, `npm run format:check` |
| M1-02 | Frontend skeleton + esbuild + Jest/ESLint/Prettier | 18 Nov | ✅ | ✅ | `npm run build` (`dist/`), `npm test` (jsdom), `npm run lint`, `npm run format:check` |
| M1-03 | Tasks API CRUD (tests first, 400/404 covered) | 20 Nov | ✅ | ✅ | `npm test` (12/12 backend tests incl. 400/404, mocked repo), `npm run lint`, `npm run format:check` |
| M1-04 | Postgres repository + env config + auto-create table | 20 Nov | ✅ | ✅ | Unit tests (`pg.Pool` mocked) + live `postgres:17.12-alpine3.24` container CRUD & schema init |
| M1-05 | Frontend task UI + tests | 21 Nov | ✅ | ✅ | `npm run build` (`dist/`), `npm test` (12/12 tests, 100% cov), `npm run lint`, `npm run format:check`, live container stack on `:8080` |
| M1-06 | Coverage ≥ 80% enforced, lcov for Sonar | 21 Nov | ✅ | ✅ | `coverageThreshold: 80` + `coverage/lcov.info` in both `jest.config.js` (96%+ backend, 91%+ frontend) |
| M1-07 | JSON request logging | 22 Nov | ✅ | ✅ | `src/logger.js` emits `{"level","msg","method","path","status","duration_ms"}` JSON lines; unit + container log verified |
| M1-08 | `APP_VERSION` in health response | 22 Nov | ✅ | ✅ | `GET /api/health` returns `APP_VERSION` (unit tested + container tested with `v1.0.99`) |
| M1-09 | k6 load test script + README | 25 Nov | ✅ | ✅ | `loadtest.yml` (k6 2.3.0 on Actions): 400 VUs, 4.35 M req @ 4.5 k/s, 0.00 % failed, p95 98 ms, ASG 2→4 · [run](https://github.com/hussainwaz/taskflow-devops/actions/runs/45887496574) |
| M1-10 | CloudWatch agent config (memory) | 23 Nov | ✅ | ✅ | `mem_used_percent` reported by CW agent on every ASG instance (22 metric streams, ~36 % on 28 Nov) |
| M1-11 | SNS topic + all members subscribed | 23 Nov | ✅ | ⬜ | `taskflow-alerts` created in `627551519533` + all 4 `@lhr.nu.edu.pk` emails subscribed; 🚧 members confirm email + test publish |
| M1-12 | Dashboard + `monitoring/dashboard.json` | 24 Nov | ✅ | ✅ | `taskflow-dashboard` re-run after `infra/up.sh` (ALB + TG widgets live) · `monitoring/dashboard.json` exported |
| M1-13 | ≥ 2 alarms, each tested | 24 Nov | ✅ | ✅ | 4 alarms; `taskflow-backend-5xx` fired + cleared in D-07, `unhealthy-*` fired during deploys/instance kill; SNS emails received |
| M1-14 | App README section + lessons for report | 29 Nov | ✅ | ⬜ | Added `Application, Testing & Monitoring` to root `README.md`; 🚧 add final lessons learned to `report.md` after demos |

## Member 2 — Containers, shell scripts, CD, README & PDF

| ID | Task | Due | Built | Tested | Proof |
|----|------|-----|-------|--------|-------|
| M2-01 | Backend Dockerfile + .dockerignore | 18 Nov | ✅ | ✅ | PR #6: Hadolint clean · `id` = uid 1000 (node) · Trivy HIGH/CRITICAL 0 · healthy in Compose (hello-world app until M1-01 lands) |
| M2-02 | Frontend Dockerfile + nginx.conf + .dockerignore | 18 Nov | ✅ | ✅ | PR #6: Hadolint clean · `id` = uid 101 (nginx) · `/health` 200 · `/api/` proxied · Trivy HIGH/CRITICAL 0 (hello-world app) |
| M2-03 | `docker-compose.yml` + `.env.example` + "Run locally" README | 19 Nov | ✅ | ✅ | PR #23: fresh clone of main (454b6e1) → `cp .env.example .env && docker compose up --build` → db, backend, frontend healthy (4 min, cold Docker) → `scripts/smoke-test.sh http://localhost:8080` passed on M1's real app (output in PR #23) |
| M2-04 | `scripts/build-and-test.sh` | 20 Nov | ✅ | ✅ | PR #7: ShellCheck clean · passes on both services · exits 1 and names the step when a unit test fails (output in PR) |
| M2-05 | `scripts/healthcheck.sh` | 20 Nov | ✅ | ✅ | PR #7: ShellCheck clean · exit 0 vs local Compose · exit 1 for a dead URL · exit 2 on bad args (output in PR) |
| M2-06 | `scripts/smoke-test.sh` | 21 Nov | ✅ | ✅ | PR #7: ShellCheck clean · passes vs local Compose · fails when backend stopped or version mismatches (output in PR) |
| M2-07 | ECR repos (immutable tags, scan on push, lifecycle) | 21 Nov | ✅ | ✅ | PR #8: created 25 Nov in 627551519533 (CloudShell, same settings as `scripts/aws-ecr-logs.sh`): IMMUTABLE, scan on push, AES256, keep newest 20 · `docs/evidence/M2-07-01-ecr-repos-console.jpg`, `M2-07-02-ecr-logs-cli-verify.jpg` |
| M2-08 | `docker-compose.prod.yml` (ECR images, awslogs, env file) | 22 Nov | ✅ | ✅ | In SSM `/taskflow/prod/compose_file`; instances run it with awslogs (fixed `{{.ID}}` tag that SSM rejects) |
| M2-09 | Job `11-push-image` (OIDC, SHA + semver tags) | 23 Nov | ✅ | ✅ | `v1.0.15` + full SHA tags in both ECR repos · [run 45877781053](https://github.com/hussainwaz/taskflow-devops/actions/runs/45877781053) |
| M2-10 | `scripts/deploy.sh` | 24 Nov | ✅ | ✅ | Real instance refreshes in deploy [run](https://github.com/hussainwaz/taskflow-devops/actions/runs/45879965344) and rollback [run](https://github.com/hussainwaz/taskflow-devops/actions/runs/45881326487) |
| M2-11 | Job `12-deploy` + auto-rollback | 25 Nov | ✅ | ✅ | Push to main auto-deployed v1.0.17 and v1.0.18, smoke test passed · [run](https://github.com/hussainwaz/taskflow-devops/actions/runs/45879965344) |
| M2-12 | `rollback.yml` manual workflow | 26 Nov | ✅ | ✅ | `rollback.yml` v1.0.17 → v1.0.15, smoke test passed · [run](https://github.com/hussainwaz/taskflow-devops/actions/runs/45881326487) |
| M2-13 | Log groups + 7-day retention | 22 Nov | ✅ | ✅ | PR #8: `/taskflow/backend` + `/taskflow/frontend`, 7-day retention, created 25 Nov · `docs/evidence/M2-13-01-log-groups-console.jpg`, `M2-07-02-ecr-logs-cli-verify.jpg`; CloudWatch log lines from EC2 follow with the first deploy |
| M2-14 | Root README final (run / deploy / teardown / links) | 29 Nov | ✅ | ✅ | PR #23: graders-facing README (links, team, architecture, run locally, 12-stage pipeline + CD + rollback, branching, network, security, deploy/teardown, scripts) · link check 27 Nov: every public link 200, every relative link exists |
| M2-15 | `GroupX.pdf` assembled and submitted | 30 Nov | ✅ | ⬜ | `node docs/submission/build-pdf.mjs` → `23L-3035_23L-3018_23L-3069_23L-3024.pdf` (no group number, so named by roll numbers); all 18 links OK; 🚧 D06-01 branch-protection screenshot, then submit |

## Member 3 — CI pipeline, DevSecOps, diagram & report

| ID | Task | Due | Built | Tested | Proof |
|----|------|-----|-------|--------|-------|
| M3-00 | `main` protected + SonarCloud/Snyk tokens in GitHub Secrets | 17 Nov | ✅ | ✅ | `SONAR_TOKEN`, `SNYK_TOKEN` in repo secrets. Branch protection removed 26 Nov (team pushes to main), see M3-10 |
| M3-01 | `pipeline.yml` skeleton, jobs chained in order | 18 Nov | ✅ | ✅ | `pipeline.yml`: jobs 2→12 chained with `needs:` · [run 45877781053](https://github.com/hussainwaz/taskflow-devops/actions/runs/45877781053) |
| M3-02 | `2-secret-scan` Gitleaks full history | 18 Nov | ✅ | ✅ | Gitleaks v8.30.1, `fetch-depth: 0` · [run 45877781053](https://github.com/hussainwaz/taskflow-devops/actions/runs/45877781053) |
| M3-03 | `3-lint` (ESLint + ShellCheck), `4-format` (Prettier) | 19 Nov | ✅ | ✅ | ESLint ×2 + ShellCheck on scripts/, infra/, monitoring/ · [run 45877781053](https://github.com/hussainwaz/taskflow-devops/actions/runs/45877781053) |
| M3-04 | `5-dockerfile-lint` Hadolint | 19 Nov | ✅ | ✅ | Hadolint v2.14.0, `--failure-threshold warning` · [run 45877781053](https://github.com/hussainwaz/taskflow-devops/actions/runs/45877781053) |
| M3-05 | `6-unit-tests` Jest + coverage | 20 Nov | ✅ | ✅ | Jest ×2, coverage ≥ 80 % enforced, `coverage` artifact · [run 45877781053](https://github.com/hussainwaz/taskflow-devops/actions/runs/45877781053) |
| M3-06 | `7-static-analysis` SonarCloud + quality gate | 20 Nov | ✅ | ✅ | SonarCloud CI scan, `sonar.qualitygate.wait=true`, gate passed · [run 45877781053](https://github.com/hussainwaz/taskflow-devops/actions/runs/45877781053) |
| M3-07 | `8-dependency-scan` Snyk + `dependabot.yml` | 21 Nov | ✅ | ✅ | Snyk 1.1308.4 `--severity-threshold=high` ×2 + `.github/dependabot.yml` (npm ×2, docker ×2, actions) · [run 45877781053](https://github.com/hussainwaz/taskflow-devops/actions/runs/45877781053) |
| M3-08 | `9-build-image` + image artifacts | 21 Nov | ✅ | ✅ | `docker save` → `images` artifact, pushed unchanged by job 11 · [run 45877781053](https://github.com/hussainwaz/taskflow-devops/actions/runs/45877781053) |
| M3-09 | `10-image-scan` Trivy HIGH/CRITICAL | 21 Nov | ✅ | ✅ | Trivy 0.76.2 HIGH/CRITICAL, `--exit-code 1`, 0 findings · [run 45877781053](https://github.com/hussainwaz/taskflow-devops/actions/runs/45877781053) |
| M3-10 | Branch protection with all required checks | 22 Nov | ⬜ | ⬜ | |
| M3-11 | `SECURITY.md` | 22 Nov | ✅ | ⬜ | `SECURITY.md`: gates, secrets, hardening, accepted findings |
| M3-12 | PR template (+ CODEOWNERS) | 18 Nov | ✅ | ⬜ | `.github/pull_request_template.md` + `.github/CODEOWNERS` |
| M3-13 | `docs/VIVA.md` live-demo script, everyone rehearsed | 28 Nov | ✅ | ⬜ | `docs/VIVA.md`; 🚧 every member runs it once |
| M3-14 | Architecture diagram (draft 20 Nov, final) | 28 Nov | ✅ | ✅ | `docs/submission/architecture.png` (source `architecture.dot`, `dot -Tpng`): 12 stages, OIDC roles, secrets, 2 AZs/4 subnets, request flow, monitoring |
| M3-15 | Findings report + contribution table | 29 Nov | ✅ | ✅ | `docs/submission/report.md`: report + contribution table with all 4 names and roll numbers |

## Member 4 — AWS infrastructure, IAM, networking & incident note

| ID | Task | Due | Built | Tested | Proof |
|----|------|-----|-------|--------|-------|
| M4-00 | AWS budget alert, IAM users + MFA, region us-east-1 | 17 Nov | ✅ | ✅ | Budget `taskflow-monthly` $25 (spend $4.24 on 28 Nov); 🚧 members confirm their own MFA login |
| M4-01 | VPC, 4 subnets, IGW, NAT, route tables | 19 Nov | ✅ | ✅ | PR #1 (`01-network.sh`, `nat.sh`); re-run creates nothing; IDs in infra/README §1–2 |
| M4-02 | Security groups (no SSH) | 19 Nov | ✅ | ✅ | PR #1 (`02-security-groups.sh`); rules in infra/README §3 |
| M4-03 | GitHub OIDC provider + CI role + deploy role | 20 Nov | ✅ | ✅ | OIDC roles assumed by job 11 (immutable subject `repo:hussainwaz@148036334/taskflow-devops@1460445754`) · [run 45877781053](https://github.com/hussainwaz/taskflow-devops/actions/runs/45877781053) |
| M4-04 | EC2 role + instance profile | 20 Nov | ✅ | ✅ | PR #1 (`iam/ec2-*.json`); instance profile exists with the role |
| M4-05 | RDS Postgres + Secrets Manager password | 21 Nov | ✅ | ✅ | `rds.sh`; not public, encrypted, db-sg only; reachable on 5432 from an app-sg instance (infra/README §7) |
| M4-06 | SSM parameters for image tags | 21 Nov | ✅ | ✅ | `04-ssm-params.sh`; both params exist (`none`) |
| M4-07 | `infra/user-data.sh` (with M2) | 22 Nov | ✅ | ✅ | ASG instances boot from SSM tag + compose file and serve `v1.0.15`; `scripts/smoke-test.sh` passed against the ALB (26 Nov) |
| M4-08 | Launch template (IMDSv2, no key pair) | 22 Nov | ✅ | ✅ | `05-launch-template.sh`; test instance: no key, no public IP, IMDSv2 required |
| M4-09 | ALB + 2 target groups + path routing | 23 Nov | ✅ | ✅ | `06-target-groups.sh`, `alb.sh`; `/`→frontend, `/api/*`→backend, both TGs healthy (infra/README §8–9) |
| M4-10 | ASG (min 2, 2 AZs, target tracking) | 23 Nov | ✅ | ✅ | 2 AZs, min 2/max 4, CPU 50 % target tracking: scaled 2→4 under load (D-04); instance kill replaced automatically (D-03) |
| M4-11 | SSM Session Manager works, SSH impossible | 23 Nov | ✅ | ✅ | Both instances `Online` in SSM, 0 security-group rules on port 22 (CLI 28 Nov) |
| M4-12 | Live link in README + `ALB_URL` variable | 23 Nov | ✅ | ✅ | http://taskflow-alb-466982077.us-east-1.elb.amazonaws.com in README + GitHub variable `ALB_URL` |
| M4-13 | `infra/README.md` complete (rebuild + teardown) | 28 Nov | ✅ | ✅ | `infra/README.md` + root README network design / deploy / teardown (PR #5) |
| M4-14 | Cost control, everything up until grading | ongoing | ✅ | ⬜ | Paid layer scripted up/down (`infra/up.sh`/`down.sh`); stays up from now until grading |
| M4-15 | Post-incident note (after D-07) | 28 Nov | ✅ | ✅ | `docs/incidents/2026-11-26-db-unreachable.md` |


## Demos & evidence — whole team together, Fri 27 / Sat 28 Nov

No owners: the team runs these together and rotates who drives (details in [WORK.md](WORK.md#demos--evidence--whole-team-together-p3-fri-27--sat-28)).

| ID | Demo | Driven by | Done | Screenshots saved |
|----|------|-----------|------|-------------------|
| D-01 | CI run, jobs 2–10 separate | Amar (CLI) — pipeline run 45879965344 | ✅ | ✅ |
| D-02 | Security stage blocks a PR | Amar (CLI) — PR #22, run 45895734843: `8-dependency-scan` (Snyk, lodash 4.17.20) failed, 9–12 skipped | ✅ | ✅ D02-01 (🚧 D02-02 merge-blocked needs branch protection) |
| D-03 | Instance terminated → stays up → recovers | Amar (CLI) — instance kill 26 Nov 19:13 UTC | ✅ | ✅ |
| D-04 | Load test → scale-out → scale-in | Amar (CLI) — loadtest run 45887496574: out 2→4 at 20:04/20:07 UTC, in 4→2 at 20:26/20:32 UTC | ✅ | ✅ |
| D-05 | Commit auto-deployed + rollback | Amar (CLI) — deploy 45879965344 + rollback 45881326487 | ✅ | ✅ |
| D-06 | Multi-AZ, OIDC trust, ECR tags, branch protection | Amar (CLI) — ECR, OIDC, subnets, ASG 2 AZs captured 28 Nov | 🚧 | 4/5: 🚧 D06-01 branch protection |
| D-07 | Deliberate failure → alarm → fix → note | Amar (CLI) — incident 26 Nov 19:27 UTC | ✅ | ✅ |

## Final submission checklist — Sun 29 / Mon 30 Nov

| # | Check | Owner | Done |
|---|-------|-------|------|
| F-01 | Every member has commits **and** PRs **and** reviews in the repo | All | ⬜ |
| F-02 | Gitleaks over full history is clean | M3 | ✅ |
| F-03 | Every Dependabot/Snyk/Trivy/Sonar finding fixed or listed in `SECURITY.md` | M3 | ⬜ |
| F-04 | README: run locally / deploy from scratch / tear down / branching strategy / network design | M2 + M4 | ✅ |
| F-05 | Workflows, Dockerfiles, Compose, scripts, `SECURITY.md` all visible in repo | M3 | ✅ |
| F-06 | Instructor + TA can access the repo (public repo, no emails given in the brief) | All | ✅ |
| F-07 | Live link opens the app from a phone (not just our laptops) | M4 | ✅ |
| F-08 | All 10 screenshot groups present in `docs/evidence/` (9/10, 🚧 D06-01 branch protection) | M2 | ⬜ |
| F-09 | PDF page 1 = all names + roll numbers | M2 | ✅ |
| F-10 | PDF links clickable (all 18 OK), named after roll numbers (no group number) | M2 | ✅ |
| F-11 | Everyone rehearsed `docs/VIVA.md` once | All | ⬜ |
| F-12 | AWS stack left running; budget alert still on | M4 | ✅ |
