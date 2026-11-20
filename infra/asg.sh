#!/usr/bin/env bash
# M4-10: Auto Scaling Group taskflow-asg (paid layer: the t3.micro instances).
#   infra/asg.sh up      create (first run) or scale back to min 2 / desired 2 / max 4
#   infra/asg.sh down    scale to 0 instances; the group, its policy and settings are kept
#   infra/asg.sh status
# Settings: launch template taskflow-lt ($Default), private-a + private-b (2 AZs), both target
# groups, ELB health checks with 180 s grace, target tracking on average CPU 50 %, group metrics on.
# Needs the NAT (image pulls) and RDS up first: use infra/up.sh.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

action="${1:-status}"
require_aws

asg_exists() {
  [[ -n "$(q aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG_NAME" \
    --query 'AutoScalingGroups[0].AutoScalingGroupName' --output text)" ]]
}

case "$action" in
  up)
    if asg_exists; then
      log "Scaling $ASG_NAME to min $ASG_MIN / desired $ASG_DESIRED / max $ASG_MAX"
      aws autoscaling update-auto-scaling-group --auto-scaling-group-name "$ASG_NAME" \
        --min-size "$ASG_MIN" --desired-capacity "$ASG_DESIRED" --max-size "$ASG_MAX"
    else
      vpc_id="$(find_vpc_id)"
      priv_a="$(q aws ec2 describe-subnets --filters "Name=tag:Name,Values=$SUBNET_PRIVATE_A" \
        "Name=vpc-id,Values=$vpc_id" --query 'Subnets[0].SubnetId' --output text)"
      priv_b="$(q aws ec2 describe-subnets --filters "Name=tag:Name,Values=$SUBNET_PRIVATE_B" \
        "Name=vpc-id,Values=$vpc_id" --query 'Subnets[0].SubnetId' --output text)"
      fe="$(find_tg_arn "$TG_FRONTEND")"
      be="$(find_tg_arn "$TG_BACKEND")"
      [[ -n "$fe" && -n "$be" ]] || die "target groups missing. Run infra/06-target-groups.sh first"
      log "Creating $ASG_NAME in $SUBNET_PRIVATE_A + $SUBNET_PRIVATE_B"
      aws autoscaling create-auto-scaling-group --auto-scaling-group-name "$ASG_NAME" \
        --launch-template "LaunchTemplateName=$LT_NAME,Version=\$Default" \
        --min-size "$ASG_MIN" --desired-capacity "$ASG_DESIRED" --max-size "$ASG_MAX" \
        --vpc-zone-identifier "$priv_a,$priv_b" \
        --target-group-arns "$fe" "$be" \
        --health-check-type ELB --health-check-grace-period 180 \
        --default-instance-warmup 120 \
        --tags "Key=Project,Value=$PROJECT,PropagateAtLaunch=true" \
               "Key=Owner,Value=$OWNER_TAG,PropagateAtLaunch=true"
    fi

    aws autoscaling put-scaling-policy --auto-scaling-group-name "$ASG_NAME" \
      --policy-name taskflow-cpu-target-tracking --policy-type TargetTrackingScaling \
      --target-tracking-configuration "$(jq -nc --argjson t "$CPU_TARGET" \
        '{PredefinedMetricSpecification: {PredefinedMetricType: "ASGAverageCPUUtilization"}, TargetValue: $t}')" \
      >/dev/null
    log "Scaling policy: target tracking, average CPU $CPU_TARGET %"
    aws autoscaling enable-metrics-collection --auto-scaling-group-name "$ASG_NAME" --granularity 1Minute
    log "ASG up. Instances become InService once both target groups report healthy."
    ;;
  down)
    if asg_exists; then
      aws autoscaling update-auto-scaling-group --auto-scaling-group-name "$ASG_NAME" \
        --min-size 0 --desired-capacity 0
      log "ASG scaled to 0 (group and policy kept). Instances terminate over the next minute."
    else
      log "$ASG_NAME does not exist"
    fi
    ;;
  status)
    if asg_exists; then
      aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG_NAME" \
        --query 'AutoScalingGroups[0].{min:MinSize,desired:DesiredCapacity,max:MaxSize,instances:Instances[].[InstanceId,AvailabilityZone,LifecycleState,HealthStatus]}' \
        --output json
    else
      echo "ASG does not exist"
    fi
    ;;
  *)
    die "usage: $0 up|down|status"
    ;;
esac
