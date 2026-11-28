# TaskFlow findings report

## What we learned

We built TaskFlow, a small task tracker with a frontend, a backend API and a Postgres database, and ran it on AWS behind a load balancer on an Auto Scaling group in two Availability Zones. Every push goes through a twelve stage GitHub Actions pipeline: secret scan, lint, format check, Dockerfile lint, unit tests, SonarCloud, Snyk, image build, Trivy, push to ECR and deploy with a smoke test. The main lesson was that most of DevOps is about making failure safe. Immutable image tags, scanning the exact image we ship, keeping the previous version ready to redeploy and alarms that reach us before a user does mattered more than the app itself.

## Main problems and how we solved them

GitHub Actions would not run on the account that first owned the repository because of a billing lock. We moved the repository to another member. After the move the AWS OIDC login failed, because GitHub now sends an immutable subject that includes the owner and repository IDs. We updated the trust policies to that subject.

SonarCloud failed at first because its automatic analysis clashed with our CI analysis. Once that was turned off, the quality gate found real issues: npm install scripts running in CI, an action not pinned to a commit, and downloads without enforced HTTPS. We fixed all of them. The one finding we accepted, the load balancer serving plain HTTP because we have no domain for a certificate, is recorded in SECURITY.md.

Our production Compose file passed every local test but failed on AWS, because SSM Parameter Store rejects values that contain double curly braces. We removed the logging tag that used them.

When an instance was terminated the app returned errors for a few seconds until the load balancer health check marked it unhealthy. The Auto Scaling group replaced it in about two and a half minutes without any action from us.

## Post incident note

We deliberately removed the security group rule that lets the app instances reach the database. The health endpoint stayed green, but every task request failed after the five second connection timeout. The taskflow-backend-5xx alarm went to ALARM and emailed the team about four and a half minutes later. The backend logs showed database connection timeouts, which pointed at the network path. Adding the rule back fixed it within seconds and no restart was needed. Next time we would add a readiness check that tests the database and run our security group script on a schedule to catch drift.

## Impact on our understanding

Security is part of the pipeline, not a step at the end: nine checks must pass before anything reaches AWS, and AWS itself has no long lived keys, no SSH and no secrets in the repository. Automation paid off as soon as a manual step would have been forgotten, and because rollback reuses the deploy job it is tested every time we deploy. Reliability meant planning for partial failure with two zones, at least two instances and health checks. On the cloud side we learned to keep costs low by scripting the paid resources so they can be brought up and down with one command.

## Contributions

| Name | Roll no. | Contributions |
|------|----------|---------------|
| Haseeb | 23L-3069 | Frontend and backend app with tests and an 80 percent coverage gate, JSON request logs, k6 load test, CloudWatch agent, dashboard, alarms and SNS |
| Hussain Nawaz | 23L-3018 | Dockerfiles, nginx, Compose files for local and production, health check, smoke test and deploy scripts, ECR and log groups, deploy and rollback workflows, final README and PDF |
| Shuja | 23L-3024 | CI pipeline stages 2 to 10, SonarCloud, Snyk and Dependabot, SECURITY.md, architecture diagram, evaluation walkthrough |
| Amar | 23L-3035 | AWS account and budget, VPC, subnets and NAT, security groups, IAM and OIDC roles, RDS and Secrets Manager, launch template and user data, load balancer, Auto Scaling group, infra README, incident note |
