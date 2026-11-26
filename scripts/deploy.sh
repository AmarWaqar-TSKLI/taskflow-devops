#!/usr/bin/env bash
# Rolls every instance in the ASG onto an image tag. Used by pipeline stage 12 and rollback.yml.
#
# Usage: scripts/deploy.sh [--keep-previous] <image_tag>
#   1. checks <image_tag> exists in both ECR repos (taskflow-backend, taskflow-frontend)
#   2. saves the live tag in /taskflow/prod/previous_image_tag (not with --keep-previous,
#      which the auto-rollback uses so "previous" keeps pointing at the last good version)
#   3. uploads docker-compose.prod.yml to /taskflow/prod/compose_file (user-data reads it)
#   4. sets /taskflow/prod/image_tag = <image_tag>
#   5. starts an ASG instance refresh (MinHealthy 100%, MaxHealthy 200%, warmup 120 s), waits for it
# Env: AWS_REGION (us-east-1) · ASG_NAME (taskflow-asg) · DEPLOY_TIMEOUT (1800 s) · POLL_INTERVAL (15 s)
# In GitHub Actions it also writes previous_tag=<tag that was live before> to $GITHUB_OUTPUT.
# Exit: 0 refresh Successful · 1 tag missing / refresh failed, cancelled or timed out · 2 bad usage
set -euo pipefail

usage() {
  sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

keep_previous=0
if [[ "${1:-}" == "--keep-previous" ]]; then
  keep_previous=1
  shift
fi
[[ $# -eq 1 ]] || usage
tag="$1"
# Version tags (v1.0.42) or 40-char git SHAs only: never "latest", never "none".
[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ || "$tag" =~ ^[0-9a-f]{40}$ ]] ||
  { echo "deploy: '$tag' is not a version tag (v1.0.42) or a full git SHA" >&2; usage; }

export AWS_REGION="${AWS_REGION:-us-east-1}" AWS_PAGER=""
asg="${ASG_NAME:-taskflow-asg}"
timeout="${DEPLOY_TIMEOUT:-1800}"
poll="${POLL_INTERVAL:-15}"
param_tag="/taskflow/prod/image_tag"
param_prev="/taskflow/prod/previous_image_tag"
param_compose="/taskflow/prod/compose_file"
compose_file="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/docker-compose.prod.yml"
repos=(taskflow-backend taskflow-frontend)

log() { printf '%s [deploy] %s\n' "$(date -u +%H:%M:%S)" "$*"; }
die() {
  printf '%s [deploy] ERROR: %s\n' "$(date -u +%H:%M:%S)" "$*" >&2
  exit 1
}
command -v aws >/dev/null || { echo "deploy: aws CLI v2 is required" >&2; exit 2; }
[[ -f "$compose_file" ]] || die "$compose_file not found"

get_param() { aws ssm get-parameter --name "$1" --query Parameter.Value --output text; }
put_param() { aws ssm put-parameter --name "$1" --type String --overwrite --value "$2" >/dev/null; }

# Prints "<status> <percent>" of the newest refresh, or nothing if the ASG never had one.
refresh_state() {
  aws autoscaling describe-instance-refreshes --auto-scaling-group-name "$asg" --max-records 1 \
    ${1:+--instance-refresh-ids "$1"} \
    --query 'InstanceRefreshes[0].[Status, PercentageComplete]' --output text
}

# wait_refresh <id> <deadline>: polls until the refresh ends; returns 0 only if Successful.
wait_refresh() {
  local id="$1" deadline="$2" status pct
  while :; do
    read -r status pct < <(refresh_state "$id")
    log "instance refresh ${id:-already running}: $status (${pct:-0}% done)"
    case "$status" in
      Successful) return 0 ;;
      Failed | Cancelled | RollbackSuccessful | RollbackFailed) return 1 ;;
    esac
    if ((SECONDS >= deadline)); then
      log "timed out after ${timeout}s, cancelling refresh $id"
      aws autoscaling cancel-instance-refresh --auto-scaling-group-name "$asg" >/dev/null || true
      return 1
    fi
    sleep "$poll"
  done
}

deadline=$((SECONDS + timeout))

log "1/5 checking $tag exists in ECR"
for repo in "${repos[@]}"; do
  aws ecr describe-images --repository-name "$repo" --image-ids "imageTag=$tag" >/dev/null 2>&1 ||
    die "image $repo:$tag not found in ECR"
done

current="$(get_param "$param_tag")"
log "2/5 live tag is $current"
if ((keep_previous)); then
  log "    --keep-previous: $param_prev left as $(get_param "$param_prev")"
elif [[ "$current" != "$tag" ]]; then
  put_param "$param_prev" "$current"
  log "    $param_prev = $current"
fi
[[ -n "${GITHUB_OUTPUT:-}" ]] && echo "previous_tag=$current" >>"$GITHUB_OUTPUT"

log "3/5 uploading docker-compose.prod.yml to $param_compose"
put_param "$param_compose" "file://$compose_file"

log "4/5 $param_tag = $tag"
put_param "$param_tag" "$tag"

log "5/5 instance refresh on $asg"
read -r status _ < <(refresh_state "")
if [[ "$status" =~ ^(Pending|InProgress|Cancelling|RollbackInProgress|Baking)$ ]]; then
  log "another refresh is $status, waiting for it first"
  wait_refresh "" "$deadline" || log "the earlier refresh did not succeed; starting ours anyway"
fi
refresh_id="$(aws autoscaling start-instance-refresh --auto-scaling-group-name "$asg" \
  --preferences '{"MinHealthyPercentage":100,"MaxHealthyPercentage":200,"InstanceWarmup":120}' \
  --query InstanceRefreshId --output text)"
log "started refresh $refresh_id"

wait_refresh "$refresh_id" "$deadline" || die "instance refresh $refresh_id did not succeed; $tag is NOT fully live"
log "done: every instance in $asg now runs $tag"
