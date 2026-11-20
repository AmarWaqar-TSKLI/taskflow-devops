#!/usr/bin/env bash
# M4-09 (part 1): the two target groups (free, stay up; the ASG registers instances into both).
#   taskflow-tg-frontend  HTTP 8080, health GET /health      -> 200
#   taskflow-tg-backend   HTTP 3000, health GET /api/health  -> 200
# Safe to re-run: settings are re-applied to existing groups.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

require_aws
vpc_id="$(find_vpc_id)"
[[ -n "$vpc_id" ]] || die "$VPC_NAME not found. Run infra/01-network.sh first"

# ensure_tg <name> <port> <health-path>
ensure_tg() {
  local name="$1" port="$2" path="$3" arn
  arn="$(find_tg_arn "$name")"
  if [[ -z "$arn" ]]; then
    log "Creating target group $name (HTTP $port, health $path)"
    arn="$(aws elbv2 create-target-group --name "$name" --protocol HTTP --port "$port" \
      --vpc-id "$vpc_id" --target-type instance \
      --health-check-protocol HTTP --health-check-path "$path" --matcher HttpCode=200 \
      --health-check-interval-seconds 10 --health-check-timeout-seconds 5 \
      --healthy-threshold-count 2 --unhealthy-threshold-count 2 \
      --tags "Key=Name,Value=$name" "Key=Project,Value=$PROJECT" "Key=Owner,Value=$OWNER_TAG" \
      --query 'TargetGroups[0].TargetGroupArn' --output text)"
  else
    log "Target group exists: $name"
    aws elbv2 modify-target-group --target-group-arn "$arn" --health-check-path "$path" \
      --matcher HttpCode=200 --health-check-interval-seconds 10 --health-check-timeout-seconds 5 \
      --healthy-threshold-count 2 --unhealthy-threshold-count 2 >/dev/null
  fi
  # 30 s deregistration delay (default 300): rolling deploys and scale-in finish faster.
  aws elbv2 modify-target-group-attributes --target-group-arn "$arn" \
    --attributes Key=deregistration_delay.timeout_seconds,Value=30 >/dev/null
  printf '%s' "$arn"
}

fe="$(ensure_tg "$TG_FRONTEND" 8080 /health)"
be="$(ensure_tg "$TG_BACKEND" 3000 /api/health)"

cat <<EOF

$TG_FRONTEND  HTTP 8080  health /health      $fe
$TG_BACKEND   HTTP 3000  health /api/health  $be
health check: every 10 s, timeout 5 s, healthy after 2, unhealthy after 2, expect 200
EOF
