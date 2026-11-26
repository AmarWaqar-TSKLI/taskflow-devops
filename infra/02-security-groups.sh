#!/usr/bin/env bash
# M4-02: the three security groups from ARCHITECTURE §4. No other inbound rules, and no port 22.
#   alb-sg  <- TCP 80 from the internet
#   app-sg  <- TCP 8080 + 3000 from alb-sg only
#   db-sg   <- TCP 5432 from app-sg only
# Safe to re-run.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

require_aws
vpc_id="$(find_vpc_id)"
[[ -n "$vpc_id" ]] || die "$VPC_NAME not found. Run infra/01-network.sh first"

ensure_sg() {
  local name="$1" desc="$2" id
  id="$(q aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$name" "Name=vpc-id,Values=$vpc_id" \
    --query 'SecurityGroups[0].GroupId' --output text)"
  if [[ -z "$id" ]]; then
    log "Creating security group $name"
    id="$(aws ec2 create-security-group --group-name "$name" --description "$desc" --vpc-id "$vpc_id" \
      --tag-specifications "$(tag_spec security-group "$name")" --query GroupId --output text)"
  else
    log "Security group exists: $name $id"
  fi
  printf '%s' "$id"
}

# allow <sg-id> <port> <source: CIDR or sg-id> <description>
allow() {
  local sg="$1" port="$2" src="$3" desc="$4" perm err
  if [[ "$src" == sg-* ]]; then
    perm="$(jq -nc --argjson p "$port" --arg s "$src" --arg d "$desc" \
      '[{IpProtocol: "tcp", FromPort: $p, ToPort: $p, UserIdGroupPairs: [{GroupId: $s, Description: $d}]}]')"
  else
    perm="$(jq -nc --argjson p "$port" --arg s "$src" --arg d "$desc" \
      '[{IpProtocol: "tcp", FromPort: $p, ToPort: $p, IpRanges: [{CidrIp: $s, Description: $d}]}]')"
  fi
  if err="$(aws ec2 authorize-security-group-ingress --group-id "$sg" --ip-permissions "$perm" 2>&1 >/dev/null)"; then
    log "$sg: allow TCP $port from $src"
  elif [[ "$err" == *InvalidPermission.Duplicate* ]]; then
    log "$sg: TCP $port from $src already allowed"
  else
    die "$err"
  fi
}

alb_sg="$(ensure_sg "$SG_ALB" "TaskFlow ALB - HTTP from the internet")"
app_sg="$(ensure_sg "$SG_APP" "TaskFlow app instances - traffic from the ALB only")"
db_sg="$(ensure_sg "$SG_DB" "TaskFlow RDS - Postgres from app instances only")"

allow "$alb_sg" 80   "0.0.0.0/0" "HTTP from the internet"
allow "$app_sg" 8080 "$alb_sg"   "frontend (nginx) from ALB"
allow "$app_sg" 3000 "$alb_sg"   "backend (Express) from ALB"
allow "$db_sg"  5432 "$app_sg"   "Postgres from app instances"

cat <<EOF

$SG_ALB  $alb_sg   in: 80 from 0.0.0.0/0
$SG_APP  $app_sg   in: 8080, 3000 from $SG_ALB
$SG_DB   $db_sg    in: 5432 from $SG_APP
(outbound: AWS default, all traffic. Port 22 is open nowhere.)
EOF
