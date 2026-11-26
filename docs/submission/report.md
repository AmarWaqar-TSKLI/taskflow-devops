# TaskFlow: findings report

## What we built and learned
TaskFlow is a small Node/Express + Postgres task app. It runs on AWS behind an Application Load Balancer,
on an Auto Scaling group that spans two Availability Zones, with RDS in private subnets. Every push to
`main` goes through an 11-job GitHub Actions pipeline: secret scan → lint → format → Dockerfile lint →
unit tests → SonarCloud gate → Snyk → image build → Trivy → push to ECR → deploy with smoke test and
automatic rollback. The biggest lesson was how much of "DevOps" is **making failure safe**, not making
success fast. That means immutable image tags, scanning the exact image we ship, keeping the previous
tag ready to redeploy, and alarms that tell us before a user does.

## Main problems and how we solved them
- **CI could not run on the repo owner's account** (GitHub billing lock). We moved the repo to another
  member's account. The AWS OIDC trust then broke, because the transferred repo uses GitHub's
  *immutable* subject claim (`repo:owner@id/repo@id`). We updated the trust policy to that form, which
  also survives repo renames.
- **SonarCloud quality gate**: Automatic Analysis clashed with CI analysis. Once that was off, the gate
  caught real problems: `npm ci` running lifecycle scripts, an unpinned action, and `curl` without HTTPS
  enforcement. We fixed all of them. The one finding we accepted (HTTP-only ALB, no domain for a
  certificate) is listed in `SECURITY.md`.
- **Deploy bug found on the real stack**: SSM Parameter Store rejects `{{ }}` in values, and our prod
  Compose file had an awslogs `tag: {{.ID}}`. It passed every local test and only failed against AWS.
- **Killing an instance gave ~20 s of 502s** before the ALB health check (10 s × 2) marked it unhealthy. The
  ASG replaced it automatically. Terminating through the ASG (which drains first) avoids those errors.

## Post-incident note (D-07)
We deliberately deleted the security-group rule that lets app instances reach Postgres. `/api/health` stayed
green, but every task request failed after the 5 s DB connection timeout. The `taskflow-backend-5xx` alarm
emailed the team after about 4.5 min. The backend's JSON logs ("Connection terminated due to connection
timeout") pointed at the network path. Re-adding the rule fixed it in 3 s, with no restart. Next time we'd
add a DB readiness check and drift detection for the security groups.
Full note: `docs/incidents/2026-11-26-db-unreachable.md`.

## Impact on our understanding
- **Security** is a pipeline property: nine gates run before anything reaches ECR, and the cloud has no
  long-lived keys (OIDC only), no SSH, and secrets only in Secrets Manager.
- **Automation** paid off the first time a manual step would have been forgotten. The rollback workflow
  re-uses the deploy job, so the rollback path gets tested on every deploy.
- **Reliability** means designing for partial failure: two AZs, min two instances, health checks, and a
  liveness check that deliberately does not depend on the DB.
- **Cloud cost**: the paid layer (NAT, ALB, ASG, RDS) was scripted to come up and down in one command, so
  we only paid for it while testing.

## Contributions

| Member | Name | Roll no. | Contributions |
|--------|------|----------|---------------|
| M1 | Haseeb | 23L-3069 | Backend + frontend app and tests (TDD, 80 % coverage gate), JSON request logs, k6 load test, CloudWatch agent, dashboard, alarms, SNS |
| M2 | Hussain | 23L-3018 | Dockerfiles, nginx, Compose (local + prod), healthcheck/smoke-test/deploy scripts, ECR + log groups, push/deploy/rollback workflows |
| M3 | Shuja | 23L-3024 | CI pipeline jobs 2–10, SonarCloud/Snyk/Dependabot, `SECURITY.md`, architecture diagram, evaluation walkthrough |
| M4 | Amar | 23L-3035 | AWS account, VPC/subnets/NAT, security groups, IAM + OIDC roles, RDS + Secrets Manager, launch template + user-data, ALB, ASG, infra README, incident note |
