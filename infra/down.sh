#!/usr/bin/env bash
# Scales the paid layer down between work sessions: ASG -> 0, ALB deleted, NAT deleted, RDS stopped.
# Nothing is lost: VPC, SGs, IAM, target groups, launch template, ASG config, DB data, ECR and SSM stay.
# Do NOT run this between submission and the end of grading (brief: deployment must stay live).
set -euo pipefail
dir="$(dirname "$0")"
"$dir/asg.sh" down
"$dir/alb.sh" down
"$dir/nat.sh" down
"$dir/rds.sh" down
