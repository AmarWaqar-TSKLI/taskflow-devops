# infra — AWS setup (rebuild & teardown guide)

**Owner:** Member 4. This file is graded: someone must be able to rebuild the whole environment from it.
Fill each section **as you create the resource** (actual values + why). Names come from
[docs/ARCHITECTURE.md §3.5](../docs/ARCHITECTURE.md#35-aws-resource-names).

Region: `us-east-1` · Tag everything `Project=taskflow`.

## How this is built: scripts, not clicks

Every resource is created by a script in this folder. The scripts **are** the rebuild instructions:
each one looks a resource up by its `Name` tag before creating it, so running them again changes nothing.
All of them pass ShellCheck and use `set -euo pipefail`.

```bash
export AWS_PROFILE=<admin profile>   # a human admin on a laptop. CI never uses keys, only OIDC roles
infra/00-budget.sh                   # needs BUDGET_EMAILS=a@x,b@y (not stored in git)
infra/00-team-users.sh               # IAM users + group for teammates
infra/01-network.sh                  # VPC, subnets, IGW, route tables       (free, stays up)
infra/02-security-groups.sh          # alb-sg, app-sg, db-sg                  (free, stays up)
infra/03-iam.sh                      # OIDC provider + 3 roles + profile      (free, stays up)
infra/nat.sh up|down|status          # NAT gateway                            (paid, on demand)
```

### Cost model: free layer always up, paid layer scaled down until submission

The brief says: *"Use small instance types, and scale down when you are not testing. Do not delete your
deployment until grading is complete."* and the live link must work at grading time. So:

| Layer | Resources | Policy |
|-------|-----------|--------|
| **Free** | VPC, subnets, IGW, route tables, security groups, IAM roles, OIDC provider, budget, SSM parameters, ECR, log groups, SNS | Created once, left up |
| **Paid (hourly)** | NAT gateway + Elastic IP, ALB, EC2/ASG, RDS | While building (until feature freeze), brought up for work/test sessions and scaled down/removed between them with the `down` scripts. **From submission until grading is complete: everything up, live link working, nothing deleted** |

## 0. Prerequisites (M4-00)
| Item | Value | Why |
|------|-------|-----|
| Account | `627551519533`, Free plan | Usage is paid from Free-plan credits |
| Region | `us-east-1` | Contract §3.1; cheapest, every service available |
| Budget | `taskflow-monthly`, $25/month, credits **excluded** | Alerts at 50 % / 80 % actual and 100 % forecast. Credits are excluded so it tracks real usage (credit burn) instead of always showing $0 |
| Team access | `00-team-users.sh`: users `hussain`, `haseeb`, `shuja` in group `taskflow-team` (PowerUserAccess + IAMReadOnlyAccess + change own password + manage own MFA, policy [`iam/team-self-mfa.json`](iam/team-self-mfa.json)). Console sign-in: `https://627551519533.signin.aws.amazon.com/console` | Own login per person, so CloudTrail shows who did what. PowerUser lets M1/M2 build CloudWatch, SNS and ECR without being able to change IAM. **No access keys**, console only; passwords are set in the console and sent privately |

## 1. VPC & subnets (M4-01): `01-network.sh`
| Resource | Name | ID | Value | Why |
|----------|------|----|-------|-----|
| VPC | `taskflow-vpc` | `vpc-01c79cb7b2f2d326c` | `10.0.0.0/16`, DNS support + hostnames on | Room to grow; DNS needed to resolve the RDS endpoint and SSM |
| Subnet | `taskflow-public-a` | `subnet-0c9d586f39d14e3fc` | `10.0.1.0/24`, us-east-1a | ALB node, NAT gateway |
| Subnet | `taskflow-public-b` | `subnet-04b19c63197d9831e` | `10.0.2.0/24`, us-east-1b | ALB node (an ALB needs 2 AZs) |
| Subnet | `taskflow-private-a` | `subnet-0595ef847733dedde` | `10.0.11.0/24`, us-east-1a | EC2 (ASG), RDS |
| Subnet | `taskflow-private-b` | `subnet-004b4e52473de9e89` | `10.0.12.0/24`, us-east-1b | EC2 (ASG), RDS subnet group |

Public subnets do **not** auto-assign public IPs: nothing we launch there needs one except the NAT,
which uses an Elastic IP. `/24` = 251 usable addresses per subnet, far more than we need.

## 2. Route tables, IGW, NAT (M4-01): `01-network.sh`, `nat.sh`
| Resource | Name | ID | Routes / notes |
|----------|------|----|----------------|
| Internet gateway | `taskflow-igw` | `igw-097405c22776700c1` | Attached to `taskflow-vpc` |
| Public route table | `taskflow-public-rt` | `rtb-08a71a6ae48dca406` | `10.0.0.0/16 → local`, `0.0.0.0/0 → IGW`. Associated: public-a, public-b |
| Private route table | `taskflow-private-rt` | `rtb-042b5fe4e4218b28c` | `10.0.0.0/16 → local`, `0.0.0.0/0 → NAT` **only while NAT is up**. Associated: private-a, private-b |
| NAT gateway | `taskflow-nat` (+ EIP `taskflow-nat-eip`) | created by `nat.sh up` | In public-a. Lets private instances pull from ECR and reach SSM/CloudWatch/Secrets Manager without public IPs |

**One NAT, not one per AZ:** saves ~$32/month. If us-east-1a fails, instances in 1b keep serving
but can't pull new images until it's back. Accepted for a student budget (ARCHITECTURE §4).

## 3. Security groups (M4-02): `02-security-groups.sh`
| SG | ID | Inbound | From | Why |
|----|----|---------|------|-----|
| `taskflow-alb-sg` | `sg-072e8361457000882` | TCP 80 | `0.0.0.0/0` | Public entry point |
| `taskflow-app-sg` | `sg-082683e451bea510f` | TCP 8080, TCP 3000 | `taskflow-alb-sg` only | Instances accept traffic **only from the ALB** |
| `taskflow-db-sg` | `sg-00c4c8860cb5c7212` | TCP 5432 | `taskflow-app-sg` only | Only app instances reach Postgres |

Outbound is the AWS default (all). **No rule for port 22 exists anywhere**; shell access is SSM
Session Manager. Rules reference security groups, not IPs, so they keep working as the ASG
replaces instances.

## 4. IAM: OIDC provider & roles (M4-03, M4-04): `03-iam.sh`
Policies are in [`iam/`](iam/), with `{{ACCOUNT_ID}}` filled in when the script applies them.

| Resource | ARN | Trusted by | Can do |
|----------|-----|-----------|--------|
| OIDC provider | `arn:aws:iam::627551519533:oidc-provider/token.actions.githubusercontent.com` | — | Audience `sts.amazonaws.com` |
| `taskflow-github-ci-role` | `arn:aws:iam::627551519533:role/taskflow-github-ci-role` | `repo:AmarWaqar-TSKLI/taskflow-devops:ref:refs/heads/main` only | Push to the two ECR repos (+ `GetAuthorizationToken`) |
| `taskflow-github-deploy-role` | `arn:aws:iam::627551519533:role/taskflow-github-deploy-role` | same, `main` only | Get/put `/taskflow/prod/*` params, instance refresh on `taskflow-asg`, `ecr:DescribeImages` |
| `taskflow-ec2-role` (+ instance profile) | `arn:aws:iam::627551519533:role/taskflow-ec2-role` | `ec2.amazonaws.com` | Read `/taskflow/prod/*` + secret `taskflow/prod/db`; managed: `AmazonSSMManagedInstanceCore`, `CloudWatchAgentServerPolicy`, `AmazonEC2ContainerRegistryReadOnly` |

Why three roles: each job gets only what it needs (least privilege). A PR from a branch or fork
can't assume any role, because the trust policy pins `sub` to the `main` branch, so only merged code
can push or deploy. There are no AWS access keys in GitHub. If a workflow job ever uses a GitHub
`environment:`, its `sub` becomes `repo:…:environment:<name>` and the trust policy must be updated.

## 5. RDS & Secrets Manager (M4-05)

## 6. SSM parameters (M4-06)

## 7. Launch template & user-data (M4-07, M4-08)
User-data: [`user-data.sh`](user-data.sh)

## 8. Load balancer & target groups (M4-09)

## 9. Auto Scaling Group & scaling policy (M4-10)

## 10. ECR (M2-07)

## 11. CloudWatch, SNS (M1 dashboard/alarms/SNS, M2 log groups)

## Deploy from scratch — order
1. `01-network.sh` (VPC, subnets, IGW, route tables), then `nat.sh up`
2. `02-security-groups.sh`
3. `03-iam.sh` (OIDC provider, roles)
4. ECR repos, then run the pipeline once to push images
5. RDS + secret, SSM parameters
6. Launch template → target groups → ALB → ASG
7. CloudWatch log groups, SNS, alarms, dashboard

## Tear down — order (ONLY after grading)
1. ASG (set to 0, then delete) → launch template
2. ALB → target groups
3. RDS (skip final snapshot) → secret
4. NAT gateway → release Elastic IP
5. VPC (removes subnets, route tables, IGW, SGs)
6. ECR repos, log groups, alarms, dashboard, SNS, SSM params
7. IAM roles + OIDC provider
8. Check Billing → no running resources

## Cost notes
Rough hourly prices (us-east-1): NAT $0.045 + EIP $0.005 · ALB ~$0.0225 + public IPv4 ·
t3.micro $0.0104 each · RDS db.t4g.micro $0.016. Everything up 24/7 ≈ $3/day, paid from Free-plan
credits ($159.87 on 20 Nov 2026). With the paid layer up only during work sessions the whole project
should use roughly $10–15 of credits before submission, plus ~$3/day from submission until grading. Check burn: `aws freetier get-account-plan-state`.
