#!/usr/bin/env bash
# Brings the whole paid layer up, in dependency order: RDS -> NAT -> ALB -> ASG.
# Run before a work/test/screenshot session, and from submission until grading is complete.
set -euo pipefail
dir="$(dirname "$0")"
"$dir/rds.sh" up
"$dir/nat.sh" up
"$dir/alb.sh" up
"$dir/asg.sh" up
"$dir/alb.sh" status
