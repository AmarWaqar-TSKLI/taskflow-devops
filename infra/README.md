# infra — AWS setup (rebuild & teardown guide)

**Owner:** Member 4. This file is graded: someone must be able to rebuild the whole environment from it.
Fill each section **as you create the resource** (actual values + why). Names come from
[docs/ARCHITECTURE.md §3.5](../docs/ARCHITECTURE.md#35-aws-resource-names).

Region: `us-east-1` · Tag everything `Project=taskflow`.

## 0. Prerequisites
- [ ] Budget alert: amount ___, emails ___
- [ ] IAM users with MFA for each member

## 1. VPC & subnets (M4-01)
| Resource | Value | Why |
|----------|-------|-----|
| VPC CIDR | 10.0.0.0/16 | |
| ... | | |

## 2. Route tables, IGW, NAT (M4-01)

## 3. Security groups (M4-02)

## 4. IAM — OIDC provider & roles (M4-03, M4-04)
Policies: [`iam/`](iam/)

## 5. RDS & Secrets Manager (M4-05)

## 6. SSM parameters (M4-06)

## 7. Launch template & user-data (M4-07, M4-08)
User-data: [`user-data.sh`](user-data.sh)

## 8. Load balancer & target groups (M4-09)

## 9. Auto Scaling Group & scaling policy (M4-10)

## 10. ECR (M2-07)

## 11. CloudWatch, SNS (M5)

## Deploy from scratch — order
1. VPC → subnets → IGW → NAT → route tables
2. Security groups
3. IAM (OIDC provider, roles)
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
