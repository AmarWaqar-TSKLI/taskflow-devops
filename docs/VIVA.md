# Evaluation walkthrough

Any member should be able to run this live. Open these tabs first:

- Repo: https://github.com/hussainwaz/taskflow-devops (Actions tab)
- App: http://taskflow-alb-466982077.us-east-1.elb.amazonaws.com
- SonarCloud: https://sonarcloud.io/project/overview?id=AmarWaqar-TSKLI_taskflow-devops
- AWS console (us-east-1): EC2 → Auto Scaling Groups → `taskflow-asg`, CloudWatch → Dashboards → `taskflow-dashboard`

Before you start, check the stack is up: `curl $ALB/api/health` should return `{"status":"ok",...,"version":"v1.0.N"}`.
If it doesn't, run `AWS_PROFILE=lab-admin infra/up.sh` (takes about 15 minutes).

## 1. Push a change and watch it deploy (about 15 min)

1. Make a visible change, e.g. edit the page heading in `services/frontend/src/render.js` and its test.
2. `main` is protected (ruleset `protection`), so a direct `git push` to it is rejected. Go through a PR,
   exactly like real work:

   ```bash
   git switch -c demo/heading
   git commit -am "demo: change heading" && git push -u origin demo/heading
   gh pr create --fill
   ```

   Show the PR page: the merge button stays blocked until checks 2–10 are green **and** one teammate approves.
   A teammate approves, then merge with **Create a merge commit**. The merge is the push to `main` that
   starts the deploy.
3. In Actions → `pipeline`, show jobs 2–10 running **one after another**. Each job is a separate stage:
   secret scan → lint → format → Dockerfile lint → unit tests → SonarCloud gate → Snyk → build → Trivy.
4. Job 11 pushes the exact scanned images to ECR with two tags: the commit SHA and `v1.0.<run number>`.
5. Job 12 points SSM at the new tag, starts an ASG instance refresh (100 % min healthy, so no downtime)
   and then runs `scripts/smoke-test.sh` against the ALB.
6. Refresh the app: the new heading shows, and `/api/health` reports the new version.

**If asked how a bad deploy is handled:** if the smoke test fails, job 12 redeploys the previous tag
(read from SSM `/taskflow/prod/previous_image_tag`) and the run still ends red.

## 2. Show a security stage blocking a change (about 5 min)

Do this on a branch so `main` stays green:

```bash
git switch -c demo/blocked
cd services/backend && npm install lodash@4.17.20 && cd ../..   # known high-severity CVEs
git commit -am "demo: vulnerable dependency" && git push -u origin demo/blocked
gh pr create --fill
```

Job `8-dependency-scan` (Snyk) fails on the high-severity lodash CVEs, and jobs 9–12 never run. Close the
PR and delete the branch afterwards. Other gates you can explain the same way: a hard-coded AWS key fails
`2-secret-scan`, and a base image with a critical CVE fails `10-image-scan`.

## 3. Manual rollback (about 12 min)

Actions → `Rollback` → Run workflow → `image_tag` = an older tag from ECR (e.g. `v1.0.15`). It checks the
tag exists in both ECR repos, then runs the same deploy and smoke test. `/api/health` shows the old version afterwards.

## 4. Resilience: kill an instance (about 5 min)

EC2 → pick one `taskflow-asg` instance → Terminate. Keep refreshing the app; it stays up because the
other AZ's instance is serving. The ASG launches a replacement within about 2 minutes (Activity tab).

## 5. Things to point at if asked

| Question | Where |
|----------|-------|
| No AWS keys in GitHub? | `infra/iam/github-*-trust.json`: OIDC, main branch of this repo only |
| Why private subnets? | README "Network design"; security groups chain ALB → app → DB, no port 22 |
| DB password? | Secrets Manager `taskflow/prod/db`, read by the EC2 role at boot |
| Scaling? | ASG target tracking at 50 % CPU, min 2 / max 4, `loadtest` workflow for proof |
| Monitoring? | CloudWatch dashboard + 4 alarms → SNS `taskflow-alerts` email |
| Accepted findings? | `SECURITY.md` |
| Who may merge to `main`? | Settings → Rules → `protection`: PR + 1 approval, checks 2–10 required, no force push or deletion |

## 6. Stage by stage: what each gate is for

If asked "why this tool?", one line each. Every stage is its own job, so a red job names the gate that stopped the change.

| Job | Tool | Why it is there | What makes it fail |
|-----|------|-----------------|--------------------|
| `2-secret-scan` | Gitleaks, full history | A key committed once stays in history even after the file is deleted | Any secret pattern in any commit |
| `3-lint` | ESLint, ShellCheck | Catches bugs and unsafe shell (unquoted variables, bad tests) before review | Any lint error |
| `4-format` | Prettier `--check` | Diffs show real changes, not whitespace | Any unformatted file |
| `5-dockerfile-lint` | Hadolint | Unpinned base images or packages, root user, bad `RUN` habits | Finding at `warning` or above |
| `6-unit-tests` | Jest + coverage | Behaviour is proven, not assumed | A failing test or coverage < 80 % |
| `7-static-analysis` | SonarCloud quality gate | Bugs, code smells, security hotspots and coverage on new code | Quality gate not passed |
| `8-dependency-scan` | Snyk | Known CVEs in npm packages (direct and transitive) | Any high or critical vulnerability |
| `9-build-image` | `docker build` + `docker save` | The image that gets scanned is the one that gets pushed (job 11 loads this artifact) | Build error |
| `10-image-scan` | Trivy | CVEs in the OS packages and runtime inside the image | Any fixable HIGH or CRITICAL CVE |
| `11-push-image` | ECR via OIDC | No stored AWS keys; immutable SHA + version tags | Runs on `main` only |
| `12-deploy` | SSM + ASG refresh + smoke test | Zero-downtime rollout with automatic rollback | Smoke test fails → previous tag redeployed, run ends red |

Order matters: cheap, fast checks run first, so a formatting mistake fails in under a minute instead of after a 5-minute build.

## Rehearsal log

Each member runs sections 1–4 once before the viva and adds a row (PROGRESS M3-13, F-11).

| Member | Date | Sections run | Notes |
|--------|------|--------------|-------|
| | | | |
