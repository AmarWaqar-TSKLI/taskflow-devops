# Security

TaskFlow is a university DevOps project. This file lists every security control in the pipeline and on
AWS, the threshold each one enforces, and every finding we decided to accept.

## Pipeline gates (`.github/workflows/pipeline.yml`)

Every push and pull request runs jobs 2–10 in order. A failure stops everything after it, so nothing
that fails a gate can reach ECR or production.

| Job | Tool | Blocks when | Config |
|-----|------|-------------|--------|
| `2-secret-scan` | Gitleaks v8.30.1, full git history | any secret pattern found | default rules |
| `3-lint` | ESLint (both services), ShellCheck (`scripts/`, `infra/`, `monitoring/`) | any error | `services/*/eslint.config.js` |
| `4-format` | Prettier `--check` | any unformatted file | `services/*/.prettierrc` |
| `5-dockerfile-lint` | Hadolint v2.14.0 | any finding at `warning` or above | `--failure-threshold warning` |
| `6-unit-tests` | Jest + coverage | failing test or coverage < 80 % | `services/*/jest.config.js` |
| `7-static-analysis` | SonarCloud | quality gate fails (scanner waits for it) | `sonar-project.properties` |
| `8-dependency-scan` | Snyk CLI | any **high** or **critical** vulnerability | `--severity-threshold=high` |
| `9-build-image` | `docker build` | build fails | `services/*/Dockerfile` |
| `10-image-scan` | Trivy 0.76.2 | any fixable **HIGH** or **CRITICAL** CVE in either image | `.trivyignore` (empty) |

Dependabot (`.github/dependabot.yml`) opens weekly update PRs for npm (×2), Docker base images (×2) and
GitHub Actions. Every third-party action and scanner image is pinned to a full commit SHA or image
digest, so a moved tag cannot change what runs in CI.

## Secrets

- **No long-lived AWS keys anywhere.** GitHub Actions gets short-lived credentials through OIDC. The trust
  policies in `infra/iam/github-*-trust.json` only accept tokens from `refs/heads/main` of this repo.
  `taskflow-github-ci-role` can push to ECR; `taskflow-github-deploy-role` can update SSM and start an ASG refresh.
- **Database password:** RDS manages it in Secrets Manager (`taskflow/prod/db`). EC2 reads it at boot
  through its instance role and writes a root-only (`0600`) env file. It is never in git or in CI.
- **GitHub secrets:** `SONAR_TOKEN` and `SNYK_TOKEN` only. Account ID, region and ALB URL are plain repo variables.
- **Local development:** `.env` is git-ignored; `.env.example` holds a dummy local-only password.

## Runtime hardening

- Containers run as non-root (`node` uid 1000, nginx uid 101), with a read-only root filesystem, all Linux
  capabilities dropped and `no-new-privileges`. npm, npx and corepack are removed from the backend runtime image.
- There is no SSH: no key pair, no port 22 in any security group. Shell access goes through SSM Session Manager.
- IMDSv2 is required on every instance.
- Network path: internet → `alb-sg` (80) → `app-sg` (3000/8080 from the ALB only) → `db-sg` (5432 from the app only).
  Instances and RDS sit in private subnets with no public IPs.
- RDS is encrypted at rest, has no public access, and the backend only connects over TLS with CA verification.
- nginx sends `X-Content-Type-Options`, `X-Frame-Options: DENY` and `Referrer-Policy`, and hides its version.

## Accepted findings

| Tool | Finding | Why accepted | Revisit |
|------|---------|--------------|---------|
| — | none so far | | |

Any finding a gate flags is either fixed or added to this table with a reason, never silently skipped.

## Reporting a problem

Open a private security advisory on this repository (Security → Advisories → Report a vulnerability) or
contact any team member listed in [docs/WORK.md](docs/WORK.md). Please don't open a public issue.
