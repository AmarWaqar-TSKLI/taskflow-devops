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
| Member setup | Each member | 0 / 3 |
| App, tests & monitoring | M1 | 0 / 14 |
| Containers, scripts, CD & PDF | M2 | 0 / 15 |
| CI, DevSecOps, diagram & report | M3 | 0 / 16 |
| AWS infra & incident note | M4 | 0 / 16 |
| Demos | Whole team | 0 / 7 |
| Submission | Whole team | 0 / 12 |

---

## Member setup — each member, by Tue 17 Nov

Tick your own initials when done.

| ID | Task | M1 | M2 | M3 | M4 |
|----|------|----|----|----|----|
| T-01 | Your row in the Team table filled | ⬜ | ⬜ | ⬜ | ⬜ |
| T-02 | Tools installed | ⬜ | ⬜ | ⬜ | ⬜ |
| T-03 | Docs read | ⬜ | ⬜ | ⬜ | ⬜ |

## Member 1 — Application, tests, load test & monitoring

| ID | Task | Due | Built | Tested | Proof |
|----|------|-----|-------|--------|-------|
| M1-01 | Backend skeleton + `/api/health` + Jest/ESLint/Prettier | 17 Nov | ⬜ | ⬜ | |
| M1-02 | Frontend skeleton + esbuild + Jest/ESLint/Prettier | 18 Nov | ⬜ | ⬜ | |
| M1-03 | Tasks API CRUD (tests first, 400/404 covered) | 20 Nov | ⬜ | ⬜ | |
| M1-04 | Postgres repository + env config + auto-create table | 20 Nov | ⬜ | ⬜ | |
| M1-05 | Frontend task UI + tests | 21 Nov | ⬜ | ⬜ | |
| M1-06 | Coverage ≥ 80% enforced, lcov for Sonar | 21 Nov | ⬜ | ⬜ | |
| M1-07 | JSON request logging | 22 Nov | ⬜ | ⬜ | |
| M1-08 | `APP_VERSION` in health response | 22 Nov | ⬜ | ⬜ | |
| M1-09 | k6 load test script + README | 25 Nov | ⬜ | ⬜ | |
| M1-10 | CloudWatch agent config (memory) | 23 Nov | ⬜ | ⬜ | |
| M1-11 | SNS topic + all members subscribed | 23 Nov | ⬜ | ⬜ | |
| M1-12 | Dashboard + `monitoring/dashboard.json` | 24 Nov | ⬜ | ⬜ | |
| M1-13 | ≥ 2 alarms, each tested | 24 Nov | ⬜ | ⬜ | |
| M1-14 | App README section + lessons for report | 29 Nov | ⬜ | ⬜ | |

## Member 2 — Containers, shell scripts, CD, README & PDF

| ID | Task | Due | Built | Tested | Proof |
|----|------|-----|-------|--------|-------|
| M2-01 | Backend Dockerfile + .dockerignore | 18 Nov | ⬜ | ⬜ | |
| M2-02 | Frontend Dockerfile + nginx.conf + .dockerignore | 18 Nov | ⬜ | ⬜ | |
| M2-03 | `docker-compose.yml` + `.env.example` + "Run locally" README | 19 Nov | ⬜ | ⬜ | |
| M2-04 | `scripts/build-and-test.sh` | 20 Nov | ✅ | ✅ | PR #7: ShellCheck clean · passes on both services · exits 1 and names the step when a unit test fails (output in PR) |
| M2-05 | `scripts/healthcheck.sh` | 20 Nov | ✅ | ✅ | PR #7: ShellCheck clean · exit 0 vs local Compose · exit 1 for a dead URL · exit 2 on bad args (output in PR) |
| M2-06 | `scripts/smoke-test.sh` | 21 Nov | ✅ | ✅ | PR #7: ShellCheck clean · passes vs local Compose · fails when backend stopped or version mismatches (output in PR) |
| M2-07 | ECR repos (immutable tags, scan on push, lifecycle) | 21 Nov | ⬜ | ⬜ | |
| M2-08 | `docker-compose.prod.yml` (ECR images, awslogs, env file) | 22 Nov | ⬜ | ⬜ | |
| M2-09 | Job `11-push-image` (OIDC, SHA + semver tags) | 23 Nov | ⬜ | ⬜ | |
| M2-10 | `scripts/deploy.sh` | 24 Nov | ⬜ | ⬜ | |
| M2-11 | Job `12-deploy` + auto-rollback | 25 Nov | ⬜ | ⬜ | |
| M2-12 | `rollback.yml` manual workflow | 26 Nov | ⬜ | ⬜ | |
| M2-13 | Log groups + 7-day retention | 22 Nov | ⬜ | ⬜ | |
| M2-14 | Root README final (run / deploy / teardown / links) | 29 Nov | ⬜ | ⬜ | |
| M2-15 | `GroupX.pdf` assembled and submitted | 30 Nov | ⬜ | ⬜ | |

## Member 3 — CI pipeline, DevSecOps, diagram & report

| ID | Task | Due | Built | Tested | Proof |
|----|------|-----|-------|--------|-------|
| M3-00 | `main` protected + SonarCloud/Snyk tokens in GitHub Secrets | 17 Nov | ⬜ | ⬜ | |
| M3-01 | `pipeline.yml` skeleton, jobs chained in order | 18 Nov | ⬜ | ⬜ | |
| M3-02 | `2-secret-scan` Gitleaks full history | 18 Nov | ⬜ | ⬜ | |
| M3-03 | `3-lint` (ESLint + ShellCheck), `4-format` (Prettier) | 19 Nov | ⬜ | ⬜ | |
| M3-04 | `5-dockerfile-lint` Hadolint | 19 Nov | ⬜ | ⬜ | |
| M3-05 | `6-unit-tests` Jest + coverage | 20 Nov | ⬜ | ⬜ | |
| M3-06 | `7-static-analysis` SonarCloud + quality gate | 20 Nov | ⬜ | ⬜ | |
| M3-07 | `8-dependency-scan` Snyk + `dependabot.yml` | 21 Nov | ⬜ | ⬜ | |
| M3-08 | `9-build-image` + image artifacts | 21 Nov | ⬜ | ⬜ | |
| M3-09 | `10-image-scan` Trivy HIGH/CRITICAL | 21 Nov | ⬜ | ⬜ | |
| M3-10 | Branch protection with all required checks | 22 Nov | ⬜ | ⬜ | |
| M3-11 | `SECURITY.md` | 22 Nov | ⬜ | ⬜ | |
| M3-12 | PR template (+ CODEOWNERS) | 18 Nov | ⬜ | ⬜ | |
| M3-13 | `docs/VIVA.md` live-demo script, everyone rehearsed | 28 Nov | ⬜ | ⬜ | |
| M3-14 | Architecture diagram (draft 20 Nov, final) | 28 Nov | ⬜ | ⬜ | |
| M3-15 | Findings report + contribution table | 29 Nov | ⬜ | ⬜ | |

## Member 4 — AWS infrastructure, IAM, networking & incident note

| ID | Task | Due | Built | Tested | Proof |
|----|------|-----|-------|--------|-------|
| M4-00 | AWS budget alert, IAM users + MFA, region us-east-1 | 17 Nov | ⬜ | ⬜ | |
| M4-01 | VPC, 4 subnets, IGW, NAT, route tables | 19 Nov | ⬜ | ⬜ | |
| M4-02 | Security groups (no SSH) | 19 Nov | ⬜ | ⬜ | |
| M4-03 | GitHub OIDC provider + CI role + deploy role | 20 Nov | ⬜ | ⬜ | |
| M4-04 | EC2 role + instance profile | 20 Nov | ⬜ | ⬜ | |
| M4-05 | RDS Postgres + Secrets Manager password | 21 Nov | ⬜ | ⬜ | |
| M4-06 | SSM parameters for image tags | 21 Nov | ⬜ | ⬜ | |
| M4-07 | `infra/user-data.sh` (with M2) | 22 Nov | ⬜ | ⬜ | |
| M4-08 | Launch template (IMDSv2, no key pair) | 22 Nov | ⬜ | ⬜ | |
| M4-09 | ALB + 2 target groups + path routing | 23 Nov | ⬜ | ⬜ | |
| M4-10 | ASG (min 2, 2 AZs, target tracking) | 23 Nov | ⬜ | ⬜ | |
| M4-11 | SSM Session Manager works, SSH impossible | 23 Nov | ⬜ | ⬜ | |
| M4-12 | Live link in README + `ALB_URL` variable | 23 Nov | ⬜ | ⬜ | |
| M4-13 | `infra/README.md` complete (rebuild + teardown) | 28 Nov | ⬜ | ⬜ | |
| M4-14 | Cost control, everything up until grading | ongoing | ⬜ | ⬜ | |
| M4-15 | Post-incident note (after D-07) | 28 Nov | ⬜ | ⬜ | |


## Demos & evidence — whole team together, Fri 27 / Sat 28 Nov

No owners: the team runs these together and rotates who drives (details in [WORK.md](WORK.md#demos--evidence--whole-team-together-p3-fri-27--sat-28)).

| ID | Demo | Driven by | Done | Screenshots saved |
|----|------|-----------|------|-------------------|
| D-01 | CI run, jobs 2–10 separate | | ⬜ | ⬜ |
| D-02 | Security stage blocks a PR | | ⬜ | ⬜ |
| D-03 | Instance terminated → stays up → recovers | | ⬜ | ⬜ |
| D-04 | Load test → scale-out → scale-in | | ⬜ | ⬜ |
| D-05 | Commit auto-deployed + rollback | | ⬜ | ⬜ |
| D-06 | Multi-AZ, OIDC trust, ECR tags, branch protection | | ⬜ | ⬜ |
| D-07 | Deliberate failure → alarm → fix → note | | ⬜ | ⬜ |

## Final submission checklist — Sun 29 / Mon 30 Nov

| # | Check | Owner | Done |
|---|-------|-------|------|
| F-01 | Every member has commits **and** PRs **and** reviews in the repo | All | ⬜ |
| F-02 | Gitleaks over full history is clean | M3 | ⬜ |
| F-03 | Every Dependabot/Snyk/Trivy/Sonar finding fixed or listed in `SECURITY.md` | M3 | ⬜ |
| F-04 | README: run locally / deploy from scratch / tear down / branching strategy / network design | M2 + M4 | ⬜ |
| F-05 | Workflows, Dockerfiles, Compose, scripts, `SECURITY.md` all visible in repo | M3 | ⬜ |
| F-06 | Instructor + TA can access the repo | All | ⬜ |
| F-07 | Live link opens the app from a phone (not just our laptops) | M4 | ⬜ |
| F-08 | All 10 screenshot groups present in `docs/evidence/` | M2 | ⬜ |
| F-09 | PDF page 1 = all names + roll numbers | M2 | ⬜ |
| F-10 | PDF links clickable, named `GroupX.pdf` | M2 | ⬜ |
| F-11 | Everyone rehearsed `docs/VIVA.md` once | All | ⬜ |
| F-12 | AWS stack left running; budget alert still on | M4 | ⬜ |
