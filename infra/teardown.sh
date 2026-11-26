#!/usr/bin/env bash
# Deletes EVERYTHING this project created in AWS, in dependency order.
# ONLY after grading is complete (brief: "Do not delete your deployment until grading is complete").
# For pausing between work sessions use infra/down.sh instead; it keeps all data and config.
#
#   CONFIRM=delete-taskflow infra/teardown.sh
#
# Owned by other members but removed here too, so nothing keeps billing: ECR repos (M2),
# log groups (M2), SNS topic, alarms and dashboard (M1).
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

[[ "${CONFIRM:-}" == "delete-taskflow" ]] || die "refusing to run. Set CONFIRM=delete-taskflow (only after grading)"
require_aws
dir="$(dirname "$0")"

# Runs a delete command; "not found" style failures are fine (already gone).
try() { "$@" >/dev/null 2>&1 || true; }

log "1/9 ASG + launch template"
if aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG_NAME" \
    --query 'AutoScalingGroups[0]' --output text | grep -q .; then
  try aws autoscaling delete-auto-scaling-group --auto-scaling-group-name "$ASG_NAME" --force-delete
  while [[ -n "$(q aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG_NAME" \
      --query 'AutoScalingGroups[0].AutoScalingGroupName' --output text)" ]]; do sleep 15; done
fi
try aws ec2 delete-launch-template --launch-template-name "$LT_NAME"

log "2/9 ALB + target groups"
"$dir/alb.sh" down
for tg in "$TG_FRONTEND" "$TG_BACKEND"; do
  arn="$(find_tg_arn "$tg")"
  [[ -n "$arn" ]] && try aws elbv2 delete-target-group --target-group-arn "$arn"
done

log "3/9 RDS (no final snapshot) + secret + subnet group"
if [[ -n "$(q aws rds describe-db-instances --db-instance-identifier "$DB_ID" \
    --query 'DBInstances[0].DBInstanceIdentifier' --output text 2>/dev/null || true)" ]]; then
  try aws rds modify-db-instance --db-instance-identifier "$DB_ID" --no-deletion-protection --apply-immediately
  try aws rds delete-db-instance --db-instance-identifier "$DB_ID" --skip-final-snapshot --delete-automated-backups
  aws rds wait db-instance-deleted --db-instance-identifier "$DB_ID"
fi
try aws secretsmanager delete-secret --secret-id "$DB_SECRET" --force-delete-without-recovery
try aws rds delete-db-subnet-group --db-subnet-group-name "$DB_SUBNET_GROUP"

log "4/9 NAT gateway + Elastic IP"
"$dir/nat.sh" down

log "5/9 Security groups, route tables, subnets, IGW, VPC"
vpc_id="$(find_vpc_id)"
if [[ -n "$vpc_id" ]]; then
  # SGs reference each other: drop the rules first, then the groups.
  for sg in $(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc_id" \
      --query "SecurityGroups[?GroupName!='default'].GroupId" --output text); do
    perms="$(aws ec2 describe-security-groups --group-ids "$sg" --query 'SecurityGroups[0].IpPermissions' --output json)"
    [[ "$perms" != "[]" ]] && try aws ec2 revoke-security-group-ingress --group-id "$sg" --ip-permissions "$perms"
  done
  for sg in $(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc_id" \
      --query "SecurityGroups[?GroupName!='default'].GroupId" --output text); do
    try aws ec2 delete-security-group --group-id "$sg"
  done
  for rt in $(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc_id" \
      --query 'RouteTables[?!(Associations[?Main])].RouteTableId' --output text); do
    for assoc in $(aws ec2 describe-route-tables --route-table-ids "$rt" \
        --query 'RouteTables[0].Associations[].RouteTableAssociationId' --output text); do
      try aws ec2 disassociate-route-table --association-id "$assoc"
    done
    try aws ec2 delete-route-table --route-table-id "$rt"
  done
  for subnet in $(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" \
      --query 'Subnets[].SubnetId' --output text); do
    try aws ec2 delete-subnet --subnet-id "$subnet"
  done
  for igw in $(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc_id" \
      --query 'InternetGateways[].InternetGatewayId' --output text); do
    try aws ec2 detach-internet-gateway --internet-gateway-id "$igw" --vpc-id "$vpc_id"
    try aws ec2 delete-internet-gateway --internet-gateway-id "$igw"
  done
  aws ec2 delete-vpc --vpc-id "$vpc_id"
fi

log "6/9 ECR repos, log groups, SSM parameters"
for repo in taskflow-frontend taskflow-backend; do
  try aws ecr delete-repository --repository-name "$repo" --force
done
for lg in /taskflow/frontend /taskflow/backend; do
  try aws logs delete-log-group --log-group-name "$lg"
done
for p in "$PARAM_IMAGE_TAG" "$PARAM_PREVIOUS_TAG" "$PARAM_COMPOSE" /taskflow/prod/cloudwatch-agent; do
  try aws ssm delete-parameter --name "$p"
done

log "7/9 CloudWatch alarms + dashboard, SNS topic"
alarms="$(aws cloudwatch describe-alarms --alarm-name-prefix taskflow --query 'MetricAlarms[].AlarmName' --output text)"
# shellcheck disable=SC2086  # word splitting wanted: one argument per alarm name
[[ -n "$alarms" ]] && try aws cloudwatch delete-alarms --alarm-names $alarms
try aws cloudwatch delete-dashboards --dashboard-names taskflow-dashboard
try aws sns delete-topic --topic-arn "arn:aws:sns:$AWS_REGION:$ACCOUNT_ID:taskflow-alerts"

log "8/9 IAM roles, instance profile, OIDC provider"
try aws iam remove-role-from-instance-profile --instance-profile-name "$ROLE_EC2" --role-name "$ROLE_EC2"
try aws iam delete-instance-profile --instance-profile-name "$ROLE_EC2"
for role in "$ROLE_CI" "$ROLE_DEPLOY" "$ROLE_EC2"; do
  for pol in $(aws iam list-attached-role-policies --role-name "$role" \
      --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || true); do
    try aws iam detach-role-policy --role-name "$role" --policy-arn "$pol"
  done
  try aws iam delete-role-policy --role-name "$role" --policy-name "$role-permissions"
  try aws iam delete-role --role-name "$role"
done
try aws iam delete-open-id-connect-provider \
  --open-id-connect-provider-arn "arn:aws:iam::$ACCOUNT_ID:oidc-provider/$OIDC_HOST"

log "9/9 Done. Left on purpose: budget + team IAM users (remove by hand when the course ends)."
log "Check Billing -> Bills, and: aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=$PROJECT"
