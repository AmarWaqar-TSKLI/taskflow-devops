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
infra/04-ssm-params.sh               # image tag parameters                   (free, stays up)
infra/05-launch-template.sh          # taskflow-lt + user-data.sh             (free)
infra/06-target-groups.sh            # 2 target groups + health checks        (free)
infra/nat.sh up|down|status          # NAT gateway                            (paid, on demand)
infra/rds.sh up|down|status          # RDS Postgres + secret                  (paid, on demand)
infra/alb.sh up|down|status          # ALB + listener + /api/* rule           (paid, on demand)
infra/asg.sh up|down|status          # ASG min 2, CPU 50 % target tracking    (paid, on demand)
infra/up.sh | infra/down.sh          # whole paid layer in one go
infra/teardown.sh                    # delete everything (after grading only)
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
| `taskflow-github-ci-role` | `arn:aws:iam::627551519533:role/taskflow-github-ci-role` | `repo:hussainwaz@148036334/taskflow-devops@1460445754:ref:refs/heads/main` only | Push to the two ECR repos (+ `GetAuthorizationToken`) |
| `taskflow-github-deploy-role` | `arn:aws:iam::627551519533:role/taskflow-github-deploy-role` | same, `main` only | Get/put `/taskflow/prod/*` params, instance refresh on `taskflow-asg`, `ecr:DescribeImages` |
| `taskflow-ec2-role` (+ instance profile) | `arn:aws:iam::627551519533:role/taskflow-ec2-role` | `ec2.amazonaws.com` | Read `/taskflow/prod/*` + secret `taskflow/prod/db`; managed: `AmazonSSMManagedInstanceCore`, `CloudWatchAgentServerPolicy`, `AmazonEC2ContainerRegistryReadOnly` |

Why three roles: each job gets only what it needs (least privilege). A PR from a branch or fork
can't assume any role, because the trust policy pins `sub` to the `main` branch, so only merged code
can push or deploy. There are no AWS access keys in GitHub. If a workflow job ever uses a GitHub
`environment:`, its `sub` becomes `repo:…:environment:<name>` and the trust policy must be updated.

## 5. RDS & Secrets Manager (M4-05): `rds.sh up|down|status`
| Setting | Value | Why |
|---------|-------|-----|
| Instance | `taskflow-db`, Postgres 17.11, `db.t4g.micro` | Smallest Graviton class, covered by the Free plan; Postgres 17 per contract §2 |
| Endpoint | `taskflow-db.cip0s8u8q9ts.us-east-1.rds.amazonaws.com` | Stored in the secret, not hard-coded anywhere |
| Storage | 20 GB gp3, encrypted (AWS-managed KMS key) | Minimum size; encryption at rest costs nothing extra |
| Network | Subnet group `taskflow-db-subnets` (private-a + private-b), SG `taskflow-db-sg`, **publicly accessible: no** | Only app instances (via `app-sg`) can reach 5432; nothing from the internet |
| Availability | Single-AZ | Multi-AZ doubles the cost. The subnet group already spans 2 AZs, so switching later is one setting |
| Backups | 1 day retention, deletion protection **on** | Protects against an accidental delete before grading. Teardown must disable it first |
| Credentials | Secret `taskflow/prod/db` = `{host, port, dbname, username, password}` | Password generated by Secrets Manager (32 chars), passed straight to RDS, never printed or committed. EC2 reads it through `taskflow-ec2-role` |

`rds.sh down` **stops** the instance (no instance-hours billed; storage still is). AWS restarts a
stopped instance automatically after 7 days, so check `rds.sh status` during long pauses.

## 6. SSM parameters (M4-06): `04-ssm-params.sh`
| Parameter | Initial value | Written by | Read by |
|-----------|---------------|-----------|---------|
| `/taskflow/prod/image_tag` | `none` | `scripts/deploy.sh` (stage 12, rollback) | `user-data.sh` at boot, to choose which images to pull |
| `/taskflow/prod/previous_image_tag` | `none` | `scripts/deploy.sh`, before changing `image_tag` | auto-rollback in stage 12 |

Standard tier `String` parameters (free). The script never overwrites an existing value, because
after the first deploy these hold the live version.

## 7. Launch template & user-data (M4-07, M4-08): `05-launch-template.sh`, `user-data.sh`
| Setting | Value | Why |
|---------|-------|-----|
| Name | `taskflow-lt` (re-running the script adds a version and makes it default) | ASG always launches the default version |
| AMI | Latest Amazon Linux 2023 x86_64, from public SSM param `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64` | Patched base, SSM agent + AWS CLI preinstalled |
| Instance type | `t3.micro` | Smallest general-purpose type the brief allows; 2 vCPU burst for the load test |
| Key pair | **none** | SSH is closed; shell access is SSM Session Manager |
| Metadata | **IMDSv2 required**, hop limit 2 | Blocks SSRF-style credential theft via IMDSv1; hop 2 lets containers reach IMDS if ever needed |
| IAM | instance profile `taskflow-ec2-role` | ECR pull, read tag/compose/secret, CloudWatch, SSM |
| Network | SG `taskflow-app-sg`, no public IP (subnets come from the ASG) | Only the ALB can reach the instance |
| Disk | 8 GB gp3, encrypted, deleted on termination | Smallest root volume for AL2023 |

**What `user-data.sh` does at boot:** installs Docker, Compose plugin `v2.32.4` (checksum-verified)
and the CloudWatch agent → starts the agent with `/taskflow/prod/cloudwatch-agent` if present →
reads `/taskflow/prod/image_tag` (if `none`, stops here) → writes `/opt/taskflow/docker-compose.prod.yml`
(from `/taskflow/prod/compose_file`), `.env` and `backend.env` (0600, DB secret) → ECR login →
`docker compose pull && up -d`. Full log on the instance: `/var/log/taskflow-user-data.log`.

**Tested 20 Nov 2026** (one instance from `taskflow-lt` in private-a, NAT up, then terminated):
private IP only, no public IP, no key pair, IMDSv2 `required` · SSM agent Online (Session Manager
works without SSH) · user-data finished, Docker + Compose v2.32.4 installed · instance reaches RDS on
5432 (app-sg → db-sg) · reads the DB secret, `backend.env` built with all 5 keys at mode 600 · an
attempt to *write* `/taskflow/prod/image_tag` from the instance is denied (role is read-only).

## 8. Load balancer & target groups (M4-09): `06-target-groups.sh`, `alb.sh up|down|status`
| Setting | Value | Why |
|---------|-------|-----|
| ALB | `taskflow-alb`, internet-facing, IPv4, public-a + public-b, SG `taskflow-alb-sg` | Only public entry point; spans 2 AZs |
| Listener | HTTP :80, default → `taskflow-tg-frontend` | Static UI and `/health` |
| Rule (priority 10) | path `/api/*` → `taskflow-tg-backend` | Browser always calls relative `/api/...`, so one origin, no CORS |
| `taskflow-tg-frontend` | HTTP 8080, health `GET /health` → 200 | Frontend container's health endpoint |
| `taskflow-tg-backend` | HTTP 3000, health `GET /api/health` → 200 | Liveness only, never touches the DB (contract §3.2) |
| Health check | every 10 s, timeout 5 s, healthy after 2, unhealthy after 2 | A dead instance leaves rotation within ~20 s |
| Deregistration delay | 30 s (default 300) | Rolling deploys and scale-in finish faster |
| Invalid header fields | dropped | Request-smuggling defence, no cost |

`alb.sh up` writes `http://<dns>` into the GitHub variable **`ALB_URL`** (used by the smoke test),
because a re-created ALB gets a new DNS name. Target groups are free and always stay.

## 9. Auto Scaling Group & scaling policy (M4-10): `asg.sh up|down|status`
| Setting | Value | Why |
|---------|-------|-----|
| Name | `taskflow-asg` | Contract |
| Launch template | `taskflow-lt`, version `$Default` | `05-launch-template.sh` updates the default; an instance refresh rolls it out |
| Subnets | private-a (us-east-1a) + private-b (us-east-1b) | ≥ 2 AZs, no public IPs |
| Size | min **2** / desired 2 / max 4 | Brief: min 2. One instance per AZ survives the loss of an instance or an AZ |
| Target groups | both | Each instance runs both containers |
| Health check | **ELB**, grace 180 s | An instance whose containers fail health checks is replaced, not just a dead VM |
| Instance warm-up | 120 s | New instances don't skew the CPU average while booting |
| Scaling policy | `taskflow-cpu-target-tracking`: average CPU **50 %** | Scales out under load, back in afterwards |
| Group metrics | enabled, 1 minute | Desired/InService graphs for the scaling evidence |

`asg.sh down` sets min/desired to 0. The group and its policy are kept, so `asg.sh up` restores it.

**Tested 20 Nov 2026** with a throwaway placeholder container on both ports (the real images did not
exist yet; placeholder removed and `image_tag` set back to `none` afterwards): 2 instances InService,
one in each AZ, both target groups healthy after ~90 s · `GET /` → frontend 200, `GET /api/health` →
backend 200 through the ALB · port 3000 not reachable from the internet · **one instance terminated
under traffic**: ASG launched a replacement, InService again after ~1 min 50 s. 11 of 12 requests
during that window succeeded; the one failure came before the ALB marked the instance unhealthy, so
health checks were tightened from 15 s × 3 to 10 s × 2.

### Session Manager instead of SSH (M4-11)
Instances have no key pair, no public IP, and no security group allows port 22. Every instance
registered with SSM (`aws ssm describe-instance-information` → Online). Shell:
`aws ssm start-session --target <instance-id>` or EC2 console → Connect → Session Manager.

## 10. ECR (M2-07): `scripts/aws-ecr-logs.sh up|status`
| Setting | Value | Why |
|---------|-------|-----|
| Repositories | `taskflow-backend`, `taskflow-frontend` | One per service, names from ARCHITECTURE §3.5 |
| Tag mutability | **IMMUTABLE** | A tag (`v1.0.N`, git SHA) always means the same image, so rollback to a tag is exact |
| Scan on push | on | Second scan by AWS on top of Trivy in stage 10 |
| Encryption | AES256 | Default at-rest encryption, no KMS cost |
| Lifecycle | keep the newest 20 images | Bounded storage cost, still ~20 versions to roll back to |
| Tags | `Project=taskflow`, `Owner=M2` | Cost tracking, teardown by tag |

Created 25 Nov 2026 (proof: `docs/evidence/M2-07-*.jpg`). Pushed to only by `taskflow-github-ci-role`
(stage 11); EC2 pulls with `AmazonEC2ContainerRegistryReadOnly`.

## 11. CloudWatch, SNS (M1 dashboard/alarms/SNS, M2 log groups)
- **Log groups (M2-13):** `/taskflow/backend`, `/taskflow/frontend`, **7-day retention**, created by
  `scripts/aws-ecr-logs.sh up` (proof: `docs/evidence/M2-13-01-log-groups-console.jpg`). Containers write to
  them through the `awslogs` driver in `docker-compose.prod.yml` (non-blocking mode, so a CloudWatch delay
  never stalls the app). Groups must exist first: the driver does not create them.
- Dashboard, alarms, SNS: see [monitoring/](../monitoring/README.md) (M1).

## Deploy from scratch: order
```bash
export AWS_PROFILE=<admin profile>
BUDGET_EMAILS=... infra/00-budget.sh
infra/00-team-users.sh
infra/01-network.sh
infra/02-security-groups.sh
infra/03-iam.sh                 # then set GitHub variables AWS_ACCOUNT_ID, AWS_REGION
infra/04-ssm-params.sh
infra/05-launch-template.sh
infra/06-target-groups.sh
scripts/aws-ecr-logs.sh up      # M2: ECR repos + log groups; first merge to main pushes images (stage 11)
infra/up.sh                     # RDS -> NAT -> ALB (sets ALB_URL) -> ASG
# M1: SNS topic, alarms, dashboard, CloudWatch agent config in SSM
```

## Pause between work sessions (not during grading)
```bash
infra/down.sh    # ASG -> 0, ALB deleted, NAT deleted, RDS stopped. Config and data kept
infra/up.sh      # back in ~10 minutes (RDS start is the slow part)
```

## Tear down: ONLY after grading
```bash
CONFIRM=delete-taskflow infra/teardown.sh
```
Order it follows: ASG → launch template → ALB → target groups → RDS (deletion protection off, no
final snapshot) → secret → DB subnet group → NAT + Elastic IP → security groups → route tables →
subnets → IGW → VPC → ECR repos → log groups → SSM parameters → alarms, dashboard, SNS →
IAM roles, instance profile, OIDC provider. Budget and team IAM users are left on purpose.
Finally check Billing and `aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=taskflow`.

## Cost notes
Rough hourly prices (us-east-1): NAT $0.045 + EIP $0.005 · ALB ~$0.0225 + public IPv4 ·
t3.micro $0.0104 each · RDS db.t4g.micro $0.016. Everything up 24/7 ≈ $3/day, paid from Free-plan
credits ($159.87 on 20 Nov 2026). With the paid layer up only during work sessions the whole project
should use roughly $10–15 of credits before submission, plus ~$3/day from submission until grading. Check burn: `aws freetier get-account-plan-state`.
