#!/usr/bin/env bash
# On-demand NAT gateway (paid layer: ~$0.045/h + Elastic IP ~$0.005/h).
#   infra/nat.sh up     create EIP + NAT in public-a, point the private route table at it
#   infra/nat.sh down   remove the private default route, delete the NAT, release the EIP
#   infra/nat.sh status
# Private instances need the NAT to pull images and reach ECR/SSM/CloudWatch, so it must be up
# whenever the ASG is running. Bring it down when the app layer is down.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

action="${1:-status}"
require_aws
vpc_id="$(find_vpc_id)"
[[ -n "$vpc_id" ]] || die "$VPC_NAME not found. Run infra/01-network.sh first"

find_nat() {
  q aws ec2 describe-nat-gateways \
    --filter "Name=tag:Name,Values=$NAT_NAME" "Name=state,Values=pending,available" \
    --query 'NatGateways[0].NatGatewayId' --output text
}
find_eip() {
  q aws ec2 describe-addresses --filters "Name=tag:Name,Values=$NAT_EIP_NAME" \
    --query 'Addresses[0].AllocationId' --output text
}
private_rt="$(q aws ec2 describe-route-tables \
  --filters "Name=tag:Name,Values=$RT_PRIVATE_NAME" "Name=vpc-id,Values=$vpc_id" \
  --query 'RouteTables[0].RouteTableId' --output text)"
[[ -n "$private_rt" ]] || die "$RT_PRIVATE_NAME not found. Run infra/01-network.sh first"

case "$action" in
  up)
    nat_id="$(find_nat)"
    if [[ -z "$nat_id" ]]; then
      eip_alloc="$(find_eip)"
      if [[ -z "$eip_alloc" ]]; then
        log "Allocating Elastic IP $NAT_EIP_NAME"
        eip_alloc="$(aws ec2 allocate-address --domain vpc \
          --tag-specifications "$(tag_spec elastic-ip "$NAT_EIP_NAME")" --query AllocationId --output text)"
      fi
      pub_a="$(q aws ec2 describe-subnets \
        --filters "Name=tag:Name,Values=$SUBNET_PUBLIC_A" "Name=vpc-id,Values=$vpc_id" \
        --query 'Subnets[0].SubnetId' --output text)"
      log "Creating NAT gateway $NAT_NAME in $SUBNET_PUBLIC_A (1-2 minutes)"
      nat_id="$(aws ec2 create-nat-gateway --subnet-id "$pub_a" --allocation-id "$eip_alloc" \
        --tag-specifications "$(tag_spec natgateway "$NAT_NAME")" \
        --query NatGateway.NatGatewayId --output text)"
    else
      log "NAT gateway exists: $nat_id"
    fi
    aws ec2 wait nat-gateway-available --nat-gateway-ids "$nat_id"
    if ! aws ec2 create-route --route-table-id "$private_rt" --destination-cidr-block 0.0.0.0/0 \
        --nat-gateway-id "$nat_id" >/dev/null 2>&1; then
      aws ec2 replace-route --route-table-id "$private_rt" --destination-cidr-block 0.0.0.0/0 \
        --nat-gateway-id "$nat_id"
    fi
    log "NAT up: $nat_id, $RT_PRIVATE_NAME 0.0.0.0/0 -> NAT"
    ;;
  down)
    if aws ec2 delete-route --route-table-id "$private_rt" --destination-cidr-block 0.0.0.0/0 2>/dev/null; then
      log "Removed 0.0.0.0/0 route from $RT_PRIVATE_NAME"
    fi
    nat_id="$(find_nat)"
    if [[ -n "$nat_id" ]]; then
      log "Deleting NAT gateway $nat_id (1-2 minutes)"
      aws ec2 delete-nat-gateway --nat-gateway-id "$nat_id" >/dev/null
      aws ec2 wait nat-gateway-deleted --nat-gateway-ids "$nat_id"
    fi
    eip_alloc="$(find_eip)"
    if [[ -n "$eip_alloc" ]]; then
      aws ec2 release-address --allocation-id "$eip_alloc"
      log "Released Elastic IP $eip_alloc"
    fi
    log "NAT down. Nothing in this layer is billing now."
    ;;
  status)
    nat_id="$(find_nat)"
    if [[ -n "$nat_id" ]]; then echo "NAT UP ($nat_id), billing hourly"; else echo "NAT DOWN"; fi
    ;;
  *)
    die "usage: $0 up|down|status"
    ;;
esac
