# evidence — screenshots for the PDF

Name files `<demo-id>-<nn>-<what>.png` so they sort in PDF order. Each one needs the **URL bar / account /
timestamp visible** where possible, so it is clearly ours and real.

| Required screenshot (from the brief) | Demo | Example filenames |
|--------------------------------------|------|-------------------|
| CI run, each stage a separate job | D-01 | `D01-01-pipeline-jobs.png` |
| Security stage failed and blocked a PR | D-02 | `D02-01-snyk-failed.png`, `D02-02-merge-blocked.png` |
| Branch protection for main | D-06 | `D06-01-branch-protection.png` |
| ECR with tagged images | D-06 | `D06-02-ecr-backend-tags.png` |
| IAM OIDC trust policy | D-06 | `D06-03-oidc-trust-policy.png` |
| Multi-zone setup | D-06 | `D06-04-subnets.png`, `D06-05-asg-instances-2-azs.png` |
| Failure recovery | D-03 | `D03-01-terminate.png`, `D03-02-app-still-up.png`, `D03-03-asg-replaced.png` |
| Load test scale-out & scale-in | D-04 | `D04-01-k6.png`, `D04-02-cpu-graph.png`, `D04-03-asg-activity.png` |
| Commit deployed automatically + rollback | D-05 | `D05-01-deploy-run.png`, `D05-02-version-live.png`, `D05-03-rollback-run.png` |
| Dashboard + fired alarm | D-07 | `D07-01-dashboard.png`, `D07-02-alarm-in-alarm.png`, `D07-03-sns-email.png` |
