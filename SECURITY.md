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
GitHub Actions. Dependabot security alerts are enabled too. The first alert, GHSA-g3hv-75wg-m249 (medium, `minimatch` < 11.0.1 pulled in by Jest as a dev dependency), was fixed with an npm `overrides` pin to `minimatch` ^11.0.9 in both services. Every third-party action and scanner image is pinned to a full commit SHA or image
digest, so a moved tag cannot change what runs in CI.

`.trivyignore` is committed at the repo root and holds no CVE IDs. Adding one needs a row in
[Accepted findings](#accepted-findings) in the same PR. `--ignore-unfixed` skips CVEs that have no patched
package yet, because there is nothing to upgrade to. The local scan below checks those too.

## Branch protection (`main`)

Ruleset `protection` (Settings → Rules) is active on `main`:

- changes only through a pull request with **1 approving review**;
- the 9 status checks `2-secret-scan` … `10-image-scan` must pass before merge;
- no force push (`non_fast_forward`) and the branch can't be deleted.

So a change that fails a gate can't be merged. Demo D-02 showed this (PR #22, Snyk failed and the merge was blocked).

## Dependabot status (28 Nov)

All Dependabot PRs show red `7-static-analysis`. Dependabot-triggered runs get no Actions secrets, so
`SONAR_TOKEN` is empty and the scanner stops with "Not authorized" before analysing anything. A repo admin
can fix this by adding `SONAR_TOKEN` and `SNYK_TOKEN` under Settings → Secrets → **Dependabot**. Until then,
an update we want is redone on a team branch so every gate really runs.

| PR | Update | Decision | Why |
|----|--------|----------|-----|
| #21 | `sonarqube-scan-action` 8.4.1 → 8.5.1 | Taken, redone as #29 | Patch release (scanner CLI + JDK update), same commit pin |
| #16, #20 | `node` 24 → 26 base image (frontend build stage, backend) | Deferred until after grading | Major runtime change during feature freeze. The contract and CI use Node 24 (LTS, supported to 2028), and the current images have 0 HIGH/CRITICAL CVEs |
| #17 | `nginx-unprivileged` 1.30.8 → 1.31.10 | Deferred until after grading | 1.31 is nginx's mainline branch; we stay on the 1.30 stable branch. The current image has 0 HIGH/CRITICAL CVEs |

Dependabot security alerts: GHSA-g3hv-75wg-m249 (`minimatch`, 2 alerts) is **fixed**, see above.
GHSA-3g3m-2fjr-6pw4 (`glob`, 2 alerts) is **auto-dismissed** by GitHub as a development-scope dependency
and is listed in [Accepted findings](#accepted-findings).

## Scan results (28 Nov, local re-check of every gate's findings)

| Check | Result |
|-------|--------|
| Gitleaks, full history | Clean (`2-secret-scan` green on `main`) |
| SonarCloud | Quality gate passed · 0 security hotspots · 1 open code smell (accepted below) |
| Snyk / `npm audit --package-lock-only` | 0 high, 0 critical in both services. 17 moderate entries per service, all from the one `glob` advisory below |
| Trivy 0.76.2 **without** `--ignore-unfixed`, both images built from `main` | 0 HIGH, 0 CRITICAL (alpine 3.24.4 packages + backend Node.js packages) |
| Dependabot alerts | 4 total: 2 fixed, 2 auto-dismissed (accepted below) |

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
| SonarCloud `shell:S5332` | `infra/alb.sh` prints/stores the ALB URL as `http://` | No domain name, so no ACM certificate for an HTTPS listener. Traffic inside AWS is private-subnet only. Suppressed in `sonar-project.properties` | If a domain is added |
| SonarCloud `javascript:S8786` (code smell, major) | `loadtest/load.js:4`: `/\/+$/` can backtrack on a long run of `/` | Not a vulnerability. It runs once per k6 VU on our own `BASE_URL` value, never on user input, and the file is in no image. Not suppressed, so it stays visible in SonarCloud; quality gate passes | Next change to `load.js` (M1) |
| Dependabot / npm audit `GHSA-3g3m-2fjr-6pw4` (medium) | `glob` 13.0.7 and 10.5.0: an aborted async walk keeps reading directories | Development-only (Jest 30 needs `glob` ^13, its coverage helper `test-exclude` needs ^10), so it isn't in either runtime image (Trivy found 0 in the backend's Node.js packages). Jest walks only our own repo and passes no `AbortSignal`. Below Snyk's high threshold. The fix is `glob` 14.0.2, a new major that Jest's ranges don't allow, so an override could break the test runner | When Jest ships with `glob` ≥ 14.0.2 |

Any finding a gate flags is either fixed or added to this table with a reason, never silently skipped.

## Reporting a problem

Open a private security advisory on this repository (Security → Advisories → Report a vulnerability) or
contact any team member listed in [docs/WORK.md](docs/WORK.md). Please don't open a public issue.
