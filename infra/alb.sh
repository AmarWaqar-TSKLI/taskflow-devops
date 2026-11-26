#!/usr/bin/env bash
# M4-09 (part 2): Application Load Balancer (paid layer: ~$0.0225/h + public IPv4).
#   infra/alb.sh up      internet-facing ALB in both public subnets, alb-sg, HTTP :80 listener:
#                          /api/*  -> taskflow-tg-backend
#                          default -> taskflow-tg-frontend
#                        then stores http://<dns> in the GitHub variable ALB_URL (if gh is logged in)
#   infra/alb.sh down    delete the ALB (target groups stay)
#   infra/alb.sh status
# The DNS name changes when the ALB is re-created, which is why `up` refreshes ALB_URL.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

action="${1:-status}"
require_aws

find_alb_arn() {
  q aws elbv2 describe-load-balancers --names "$ALB_NAME" \
    --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || true
}

case "$action" in
  up)
    vpc_id="$(find_vpc_id)"
    [[ -n "$vpc_id" ]] || die "$VPC_NAME not found. Run infra/01-network.sh first"
    fe="$(find_tg_arn "$TG_FRONTEND")"
    be="$(find_tg_arn "$TG_BACKEND")"
    [[ -n "$fe" && -n "$be" ]] || die "target groups missing. Run infra/06-target-groups.sh first"

    alb_arn="$(find_alb_arn)"
    if [[ -z "$alb_arn" ]]; then
      pub_a="$(q aws ec2 describe-subnets --filters "Name=tag:Name,Values=$SUBNET_PUBLIC_A" \
        "Name=vpc-id,Values=$vpc_id" --query 'Subnets[0].SubnetId' --output text)"
      pub_b="$(q aws ec2 describe-subnets --filters "Name=tag:Name,Values=$SUBNET_PUBLIC_B" \
        "Name=vpc-id,Values=$vpc_id" --query 'Subnets[0].SubnetId' --output text)"
      alb_sg="$(q aws ec2 describe-security-groups --filters "Name=group-name,Values=$SG_ALB" \
        "Name=vpc-id,Values=$vpc_id" --query 'SecurityGroups[0].GroupId' --output text)"
      log "Creating ALB $ALB_NAME in $SUBNET_PUBLIC_A + $SUBNET_PUBLIC_B"
      alb_arn="$(aws elbv2 create-load-balancer --name "$ALB_NAME" --type application \
        --scheme internet-facing --ip-address-type ipv4 \
        --subnets "$pub_a" "$pub_b" --security-groups "$alb_sg" \
        --tags "Key=Name,Value=$ALB_NAME" "Key=Project,Value=$PROJECT" "Key=Owner,Value=$OWNER_TAG" \
        --query 'LoadBalancers[0].LoadBalancerArn' --output text)"
    else
      log "ALB exists: $alb_arn"
    fi
    # Drop requests with malformed headers instead of forwarding them (request-smuggling defence).
    aws elbv2 modify-load-balancer-attributes --load-balancer-arn "$alb_arn" \
      --attributes Key=routing.http.drop_invalid_header_fields.enabled,Value=true >/dev/null

    listener="$(q aws elbv2 describe-listeners --load-balancer-arn "$alb_arn" \
      --query "Listeners[?Port==\`80\`].ListenerArn | [0]" --output text)"
    if [[ -z "$listener" ]]; then
      log "Creating HTTP :80 listener (default -> $TG_FRONTEND)"
      listener="$(aws elbv2 create-listener --load-balancer-arn "$alb_arn" --protocol HTTP --port 80 \
        --default-actions "Type=forward,TargetGroupArn=$fe" \
        --query 'Listeners[0].ListenerArn' --output text)"
    fi
    has_rule="$(q aws elbv2 describe-rules --listener-arn "$listener" \
      --query "Rules[?Conditions[?Field=='path-pattern' && contains(Values, '/api/*')]] | [0].RuleArn" \
      --output text)"
    if [[ -z "$has_rule" ]]; then
      log "Adding rule: /api/* -> $TG_BACKEND"
      aws elbv2 create-rule --listener-arn "$listener" --priority 10 \
        --conditions "Field=path-pattern,Values=/api/*" \
        --actions "Type=forward,TargetGroupArn=$be" >/dev/null
    fi

    aws elbv2 wait load-balancer-available --load-balancer-arns "$alb_arn"
    dns="$(aws elbv2 describe-load-balancers --load-balancer-arns "$alb_arn" \
      --query 'LoadBalancers[0].DNSName' --output text)"
    if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
      gh variable set ALB_URL --body "http://$dns" -R "$GITHUB_REPO"
      log "GitHub variable ALB_URL = http://$dns"
    fi
    log "ALB up: http://$dns"
    ;;
  down)
    alb_arn="$(find_alb_arn)"
    if [[ -n "$alb_arn" ]]; then
      log "Deleting ALB $ALB_NAME (target groups are kept)"
      aws elbv2 delete-load-balancer --load-balancer-arn "$alb_arn"
      aws elbv2 wait load-balancers-deleted --load-balancer-arns "$alb_arn"
    fi
    log "ALB down."
    ;;
  status)
    alb_arn="$(find_alb_arn)"
    if [[ -n "$alb_arn" ]]; then
      echo "ALB UP: http://$(aws elbv2 describe-load-balancers --load-balancer-arns "$alb_arn" \
        --query 'LoadBalancers[0].DNSName' --output text)"
    else
      echo "ALB DOWN"
    fi
    ;;
  *)
    die "usage: $0 up|down|status"
    ;;
esac
