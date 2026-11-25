#!/usr/bin/env bash
# M1-10..M1-13: provisions TaskFlow CloudWatch monitoring & alerts in AWS account 627551519533.
#   M1-10  uploads monitoring/cloudwatch-agent.json to SSM /taskflow/prod/cloudwatch-agent
#   M1-11  creates SNS topic taskflow-alerts and subscribes ALERT_EMAILS (comma-separated)
#   M1-12  creates/updates CloudWatch dashboard taskflow-dashboard + exports monitoring/dashboard.json
#   M1-13  creates alarms: taskflow-unhealthy-frontend, taskflow-unhealthy-backend,
#          taskflow-backend-5xx, taskflow-high-cpu
#
# Usage:
#   ALERT_EMAILS="a@x.com,b@y.com" monitoring/setup-monitoring.sh up
#   monitoring/setup-monitoring.sh status
# Env: AWS_REGION (us-east-1) · EXPECTED_ACCOUNT_ID (627551519533)
# Exit: 0 ok · 1 AWS/resource error · 2 bad usage
set -euo pipefail

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

[[ $# -eq 1 && "$1" =~ ^(up|status)$ ]] || usage
action="$1"

export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_PAGER=""

expected="${EXPECTED_ACCOUNT_ID:-627551519533}"
mon_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cw_config="$mon_dir/cloudwatch-agent.json"
dashboard_out="$mon_dir/dashboard.json"

param_cw_agent="/taskflow/prod/cloudwatch-agent"
sns_topic_name="taskflow-alerts"
dashboard_name="taskflow-dashboard"
alb_name="taskflow-alb"
tg_frontend_name="taskflow-tg-frontend"
tg_backend_name="taskflow-tg-backend"
asg_name="taskflow-asg"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() {
  printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2
  exit 1
}

command -v aws >/dev/null || {
  echo "setup-monitoring: aws CLI v2 is required" >&2
  exit 2
}

account="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)" ||
  die "not signed in to AWS (run: aws login --profile taskflow)"
[[ "$account" == "$expected" ]] ||
  die "signed in to account $account, expected $expected. Switch profile; nothing changed."
log "account $account, region $AWS_REGION"

arn_suffix() {
  # Converts full ARN (...:loadbalancer/app/name/id or ...:targetgroup/name/id) to CloudWatch dimension.
  local arn="$1"
  local suffix="${arn#*:loadbalancer/}"
  if [[ "$suffix" == "$arn" ]]; then
    suffix="${arn#*:targetgroup/}"
    printf 'targetgroup/%s' "$suffix"
  else
    printf '%s' "$suffix"
  fi
}

lookup_resources() {
  local alb_arn fe_arn be_arn
  alb_arn="$(aws elbv2 describe-load-balancers --names "$alb_name" \
    --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || true)"
  [[ -n "$alb_arn" && "$alb_arn" != "None" ]] ||
    die "$alb_name not found (run infra/up.sh first)"

  fe_arn="$(aws elbv2 describe-target-groups --names "$tg_frontend_name" \
    --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || true)"
  be_arn="$(aws elbv2 describe-target-groups --names "$tg_backend_name" \
    --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || true)"
  [[ -n "$fe_arn" && "$fe_arn" != "None" && -n "$be_arn" && "$be_arn" != "None" ]] ||
    die "target groups $tg_frontend_name / $tg_backend_name not found"

  ALB_DIM="$(arn_suffix "$alb_arn")"
  TG_FE_DIM="$(arn_suffix "$fe_arn")"
  TG_BE_DIM="$(arn_suffix "$be_arn")"
}

upload_cw_agent_param() {
  [[ -f "$cw_config" ]] || die "$cw_config not found"
  aws ssm put-parameter \
    --name "$param_cw_agent" \
    --type String \
    --overwrite \
    --value "file://$cw_config" >/dev/null
  aws ssm add-tags-to-resource \
    --resource-type Parameter \
    --resource-id "$param_cw_agent" \
    --tags Key=Project,Value=taskflow Key=Owner,Value=M1 >/dev/null
  log "SSM $param_cw_agent updated"
}

ensure_sns_topic() {
  local topic_arn email trimmed existing
  topic_arn="$(aws sns create-topic \
    --name "$sns_topic_name" \
    --tags Key=Project,Value=taskflow Key=Owner,Value=M1 \
    --query TopicArn --output text)"
  log "SNS topic $topic_arn"

  if [[ -n "${ALERT_EMAILS:-}" ]]; then
    existing="$(aws sns list-subscriptions-by-topic --topic-arn "$topic_arn" \
      --query 'Subscriptions[].Endpoint' --output text 2>/dev/null || true)"
    IFS=',' read -ra emails <<<"$ALERT_EMAILS"
    for email in "${emails[@]}"; do
      trimmed="$(printf '%s' "$email" | tr -d '[:space:]')"
      [[ -z "$trimmed" ]] && continue
      if [[ " $existing " == *" $trimmed "* ]]; then
        log "  already subscribed: $trimmed"
      else
        aws sns subscribe --topic-arn "$topic_arn" --protocol email --notification-endpoint "$trimmed" >/dev/null
        log "  subscribed $trimmed (confirm via email)"
      fi
    done
  fi
  SNS_TOPIC_ARN="$topic_arn"
}

build_dashboard_body() {
  cat <<JSON
{
  "widgets": [
    {
      "type": "metric",
      "x": 0, "y": 0, "width": 12, "height": 6,
      "properties": {
        "title": "ALB Request Rate (req/min)",
        "region": "$AWS_REGION",
        "stat": "Sum",
        "period": 60,
        "metrics": [
          ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "$ALB_DIM"]
        ]
      }
    },
    {
      "type": "metric",
      "x": 12, "y": 0, "width": 12, "height": 6,
      "properties": {
        "title": "5xx Errors (Target & ELB)",
        "region": "$AWS_REGION",
        "stat": "Sum",
        "period": 60,
        "metrics": [
          ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", "$ALB_DIM"],
          [".", "HTTPCode_ELB_5XX_Count", ".", "."]
        ]
      }
    },
    {
      "type": "metric",
      "x": 0, "y": 6, "width": 12, "height": 6,
      "properties": {
        "title": "Latency (p50 / p95 / p99)",
        "region": "$AWS_REGION",
        "period": 60,
        "metrics": [
          ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "$ALB_DIM", {"stat": "p50", "label": "p50"}],
          ["...", {"stat": "p95", "label": "p95"}],
          ["...", {"stat": "p99", "label": "p99"}]
        ]
      }
    },
    {
      "type": "metric",
      "x": 12, "y": 6, "width": 12, "height": 6,
      "properties": {
        "title": "Target Health (Healthy / UnHealthy Hosts)",
        "region": "$AWS_REGION",
        "stat": "Average",
        "period": 60,
        "metrics": [
          ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", "$TG_FE_DIM", "LoadBalancer", "$ALB_DIM", {"label": "frontend healthy"}],
          [".", "HealthyHostCount", "TargetGroup", "$TG_BE_DIM", "LoadBalancer", "$ALB_DIM", {"label": "backend healthy"}],
          [".", "UnHealthyHostCount", "TargetGroup", "$TG_FE_DIM", "LoadBalancer", "$ALB_DIM", {"label": "frontend unhealthy"}],
          [".", "UnHealthyHostCount", "TargetGroup", "$TG_BE_DIM", "LoadBalancer", "$ALB_DIM", {"label": "backend unhealthy"}]
        ]
      }
    },
    {
      "type": "metric",
      "x": 0, "y": 12, "width": 12, "height": 6,
      "properties": {
        "title": "ASG CPU Utilization (%)",
        "region": "$AWS_REGION",
        "stat": "Average",
        "period": 60,
        "metrics": [
          ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "$asg_name"]
        ]
      }
    },
    {
      "type": "metric",
      "x": 12, "y": 12, "width": 12, "height": 6,
      "properties": {
        "title": "EC2 Memory & Disk Utilization (%)",
        "region": "$AWS_REGION",
        "stat": "Average",
        "period": 60,
        "metrics": [
          ["CWAgent", "mem_used_percent", "AutoScalingGroupName", "$asg_name"],
          [".", "disk_used_percent", ".", "."]
        ]
      }
    }
  ]
}
JSON
}

put_dashboard() {
  local body
  body="$(build_dashboard_body)"
  aws cloudwatch put-dashboard \
    --dashboard-name "$dashboard_name" \
    --dashboard-body "$body" >/dev/null
  aws cloudwatch get-dashboard \
    --dashboard-name "$dashboard_name" \
    --query DashboardBody \
    --output text >"$dashboard_out"
  log "Dashboard $dashboard_name updated and exported to $dashboard_out"
}

put_alarms() {
  aws cloudwatch put-metric-alarm \
    --alarm-name taskflow-unhealthy-frontend \
    --alarm-description "UnHealthyHostCount >= 1 on taskflow-tg-frontend for 2 minutes" \
    --namespace AWS/ApplicationELB \
    --metric-name UnHealthyHostCount \
    --dimensions "Name=TargetGroup,Value=$TG_FE_DIM" "Name=LoadBalancer,Value=$ALB_DIM" \
    --statistic Maximum \
    --period 60 \
    --evaluation-periods 2 \
    --threshold 1 \
    --comparison-operator GreaterThanOrEqualToThreshold \
    --treat-missing-data notBreaching \
    --alarm-actions "$SNS_TOPIC_ARN" \
    --ok-actions "$SNS_TOPIC_ARN" \
    --tags Key=Project,Value=taskflow Key=Owner,Value=M1 >/dev/null

  aws cloudwatch put-metric-alarm \
    --alarm-name taskflow-unhealthy-backend \
    --alarm-description "UnHealthyHostCount >= 1 on taskflow-tg-backend for 2 minutes" \
    --namespace AWS/ApplicationELB \
    --metric-name UnHealthyHostCount \
    --dimensions "Name=TargetGroup,Value=$TG_BE_DIM" "Name=LoadBalancer,Value=$ALB_DIM" \
    --statistic Maximum \
    --period 60 \
    --evaluation-periods 2 \
    --threshold 1 \
    --comparison-operator GreaterThanOrEqualToThreshold \
    --treat-missing-data notBreaching \
    --alarm-actions "$SNS_TOPIC_ARN" \
    --ok-actions "$SNS_TOPIC_ARN" \
    --tags Key=Project,Value=taskflow Key=Owner,Value=M1 >/dev/null

  aws cloudwatch put-metric-alarm \
    --alarm-name taskflow-backend-5xx \
    --alarm-description "Backend HTTPCode_Target_5XX_Count > 10 in 1 min for 2 consecutive periods" \
    --namespace AWS/ApplicationELB \
    --metric-name HTTPCode_Target_5XX_Count \
    --dimensions "Name=TargetGroup,Value=$TG_BE_DIM" "Name=LoadBalancer,Value=$ALB_DIM" \
    --statistic Sum \
    --period 60 \
    --evaluation-periods 2 \
    --threshold 10 \
    --comparison-operator GreaterThanThreshold \
    --treat-missing-data notBreaching \
    --alarm-actions "$SNS_TOPIC_ARN" \
    --ok-actions "$SNS_TOPIC_ARN" \
    --tags Key=Project,Value=taskflow Key=Owner,Value=M1 >/dev/null

  aws cloudwatch put-metric-alarm \
    --alarm-name taskflow-high-cpu \
    --alarm-description "ASG average CPUUtilization > 80% for 5 minutes" \
    --namespace AWS/EC2 \
    --metric-name CPUUtilization \
    --dimensions "Name=AutoScalingGroupName,Value=$asg_name" \
    --statistic Average \
    --period 300 \
    --evaluation-periods 1 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --treat-missing-data notBreaching \
    --alarm-actions "$SNS_TOPIC_ARN" \
    --ok-actions "$SNS_TOPIC_ARN" \
    --tags Key=Project,Value=taskflow Key=Owner,Value=M1 >/dev/null

  log "Alarms created/updated: taskflow-unhealthy-frontend, taskflow-unhealthy-backend, taskflow-backend-5xx, taskflow-high-cpu"
}

show_status() {
  log "SSM parameter"
  aws ssm get-parameter --name "$param_cw_agent" --query 'Parameter.{Name:Name,Version:Version}' --output table 2>/dev/null ||
    echo "  $param_cw_agent: missing"

  log "SNS subscriptions"
  aws sns list-subscriptions-by-topic --topic-arn "arn:aws:sns:$AWS_REGION:$account:$sns_topic_name" \
    --query 'Subscriptions[].{Endpoint:Endpoint,Status:SubscriptionArn}' --output table 2>/dev/null ||
    echo "  $sns_topic_name: missing"

  log "CloudWatch alarms"
  aws cloudwatch describe-alarms --alarm-name-prefix taskflow \
    --query 'MetricAlarms[].{Alarm:AlarmName,State:StateValue,Metric:MetricName,Threshold:Threshold}' --output table
}

if [[ "$action" == "up" ]]; then
  upload_cw_agent_param
  ensure_sns_topic
  lookup_resources
  put_dashboard
  put_alarms
fi
show_status
