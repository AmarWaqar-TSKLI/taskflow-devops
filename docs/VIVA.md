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
2. `git commit -am "demo: change heading" && git push`
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
