#!/usr/bin/env bash
# Creates (or brings back in line) M2's AWS resources. Safe to re-run: nothing is deleted.
#   ECR  taskflow-backend, taskflow-frontend   tag immutability ON, scan on push, AES256,
#                                              lifecycle: keep the newest 20 images          [M2-07]
#   Logs /taskflow/backend, /taskflow/frontend  7-day retention, used by the awslogs driver
#                                              in docker-compose.prod.yml                    [M2-13]
# Everything is tagged Project=taskflow, Owner=M2. Teardown is in infra/teardown.sh (M4).
#
# Usage: scripts/aws-ecr-logs.sh up|status
# Needs AWS CLI v2 signed in to the TaskFlow account (no access keys), e.g. AWS CloudShell, or
#   aws login --profile taskflow && AWS_PROFILE=taskflow scripts/aws-ecr-logs.sh up
# Env: AWS_REGION (us-east-1) · EXPECTED_ACCOUNT_ID (627551519533): refuses any other account
# Exit: 0 ok · 1 AWS error / wrong account · 2 bad usage
set -euo pipefail

usage() {
  sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}
[[ $# -eq 1 && "$1" =~ ^(up|status)$ ]] || usage
action="$1"

export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION" AWS_PAGER=""
expected="${EXPECTED_ACCOUNT_ID:-627551519533}"
repos=(taskflow-backend taskflow-frontend)
log_groups=(/taskflow/backend /taskflow/frontend)
retention_days=7
keep_images=20

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() {
  printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2
  exit 1
}
command -v aws >/dev/null || { echo "aws CLI v2 is required" >&2; exit 2; }

account="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)" ||
  die "not signed in to AWS (see usage: AWS CloudShell or 'aws login --profile taskflow')"
[[ "$account" == "$expected" ]] ||
  die "signed in to account $account, but TaskFlow is $expected. Switch profile; nothing was changed."
log "account $account, region $AWS_REGION"

lifecycle_policy="$(cat <<JSON
{"rules":[{"rulePriority":1,"description":"keep the newest $keep_images images",
"selection":{"tagStatus":"any","countType":"imageCountMoreThan","countNumber":$keep_images},
"action":{"type":"expire"}}]}
JSON
)"

ecr_up() {
  local repo="$1"
  if aws ecr describe-repositories --repository-names "$repo" >/dev/null 2>&1; then
    log "ECR $repo exists, enforcing settings"
    aws ecr put-image-tag-mutability --repository-name "$repo" --image-tag-mutability IMMUTABLE >/dev/null
    aws ecr put-image-scanning-configuration --repository-name "$repo" \
      --image-scanning-configuration scanOnPush=true >/dev/null
  else
    log "ECR $repo: creating"
    aws ecr create-repository --repository-name "$repo" \
      --image-tag-mutability IMMUTABLE \
      --image-scanning-configuration scanOnPush=true \
      --encryption-configuration encryptionType=AES256 \
      --tags Key=Project,Value=taskflow Key=Owner,Value=M2 >/dev/null
  fi
  aws ecr put-lifecycle-policy --repository-name "$repo" --lifecycle-policy-text "$lifecycle_policy" >/dev/null
}

logs_up() {
  local group="$1" existing
  existing="$(aws logs describe-log-groups --log-group-name-prefix "$group" \
    --query "logGroups[?logGroupName=='$group'].logGroupName" --output text)"
  if [[ "$existing" == "$group" ]]; then
    log "log group $group exists"
  else
    log "log group $group: creating"
    aws logs create-log-group --log-group-name "$group" --tags Project=taskflow,Owner=M2
  fi
  aws logs put-retention-policy --log-group-name "$group" --retention-in-days "$retention_days"
}

status() {
  log "ECR repositories"
  aws ecr describe-repositories --repository-names "${repos[@]}" --output table \
    --query 'repositories[].{Name:repositoryName,TagMutability:imageTagMutability,ScanOnPush:imageScanningConfiguration.scanOnPush,URI:repositoryUri}'
  for repo in "${repos[@]}"; do
    printf '%s lifecycle: %s\n' "$repo" "$(aws ecr get-lifecycle-policy --repository-name "$repo" \
      --query lifecyclePolicyText --output text 2>/dev/null | tr -d '\n' || echo none)"
    printf '%s newest tags: %s\n' "$repo" "$(aws ecr describe-images --repository-name "$repo" \
      --query 'reverse(sort_by(imageDetails,&imagePushedAt))[:3].imageTags' --output text | tr '\n\t' '  ')"
  done
  log "CloudWatch log groups"
  aws logs describe-log-groups --log-group-name-prefix /taskflow/ --output table \
    --query 'logGroups[].{Name:logGroupName,RetentionDays:retentionInDays,StoredBytes:storedBytes}'
}

if [[ "$action" == "up" ]]; then
  for repo in "${repos[@]}"; do ecr_up "$repo"; done
  for group in "${log_groups[@]}"; do logs_up "$group"; done
  log "done"
fi
status
