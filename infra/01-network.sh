#!/usr/bin/env bash
# M4-01: VPC, 2 public + 2 private subnets across 2 AZs, internet gateway, public and private
# route tables. See ARCHITECTURE.md §4 for the design and why.
# Everything here is free, so it stays up. The NAT gateway costs money per hour, so it lives in
# infra/nat.sh (up/down) and adds the private 0.0.0.0/0 route when it is up.
# Safe to re-run: each resource is looked up by its Name tag before anything is created.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

require_aws

# --- VPC ---------------------------------------------------------------------
vpc_id="$(find_vpc_id)"
if [[ -z "$vpc_id" ]]; then
  log "Creating VPC $VPC_NAME ($VPC_CIDR)"
  vpc_id="$(aws ec2 create-vpc --cidr-block "$VPC_CIDR" \
    --tag-specifications "$(tag_spec vpc "$VPC_NAME")" --query Vpc.VpcId --output text)"
  aws ec2 wait vpc-available --vpc-ids "$vpc_id"
else
  log "VPC exists: $vpc_id"
fi
# DNS support + hostnames: needed for the RDS endpoint name and SSM to resolve inside the VPC.
aws ec2 modify-vpc-attribute --vpc-id "$vpc_id" --enable-dns-support '{"Value":true}'
aws ec2 modify-vpc-attribute --vpc-id "$vpc_id" --enable-dns-hostnames '{"Value":true}'

# --- Subnets -----------------------------------------------------------------
ensure_subnet() {
  local name="$1" cidr="$2" az="$3" id
  id="$(q aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=$name" "Name=vpc-id,Values=$vpc_id" \
    --query 'Subnets[0].SubnetId' --output text)"
  if [[ -z "$id" ]]; then
    log "Creating subnet $name ($cidr, $az)"
    id="$(aws ec2 create-subnet --vpc-id "$vpc_id" --cidr-block "$cidr" --availability-zone "$az" \
      --tag-specifications "$(tag_spec subnet "$name")" --query Subnet.SubnetId --output text)"
  else
    log "Subnet exists: $name $id"
  fi
  printf '%s' "$id"
}

pub_a="$(ensure_subnet "$SUBNET_PUBLIC_A" "$CIDR_PUBLIC_A" "$AZ_A")"
pub_b="$(ensure_subnet "$SUBNET_PUBLIC_B" "$CIDR_PUBLIC_B" "$AZ_B")"
priv_a="$(ensure_subnet "$SUBNET_PRIVATE_A" "$CIDR_PRIVATE_A" "$AZ_A")"
priv_b="$(ensure_subnet "$SUBNET_PRIVATE_B" "$CIDR_PRIVATE_B" "$AZ_B")"

# --- Internet gateway --------------------------------------------------------
igw_id="$(q aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=$IGW_NAME" \
  --query 'InternetGateways[0].InternetGatewayId' --output text)"
if [[ -z "$igw_id" ]]; then
  log "Creating internet gateway $IGW_NAME"
  igw_id="$(aws ec2 create-internet-gateway \
    --tag-specifications "$(tag_spec internet-gateway "$IGW_NAME")" \
    --query InternetGateway.InternetGatewayId --output text)"
fi
attached_vpc="$(q aws ec2 describe-internet-gateways --internet-gateway-ids "$igw_id" \
  --query 'InternetGateways[0].Attachments[0].VpcId' --output text)"
if [[ -z "$attached_vpc" ]]; then
  log "Attaching $igw_id to $vpc_id"
  aws ec2 attach-internet-gateway --internet-gateway-id "$igw_id" --vpc-id "$vpc_id"
elif [[ "$attached_vpc" != "$vpc_id" ]]; then
  die "$IGW_NAME is attached to another VPC ($attached_vpc)"
fi

# --- Route tables ------------------------------------------------------------
ensure_route_table() {
  local name="$1" id
  id="$(q aws ec2 describe-route-tables \
    --filters "Name=tag:Name,Values=$name" "Name=vpc-id,Values=$vpc_id" \
    --query 'RouteTables[0].RouteTableId' --output text)"
  if [[ -z "$id" ]]; then
    log "Creating route table $name"
    id="$(aws ec2 create-route-table --vpc-id "$vpc_id" \
      --tag-specifications "$(tag_spec route-table "$name")" \
      --query RouteTable.RouteTableId --output text)"
  fi
  printf '%s' "$id"
}

# set_default_route <route-table-id> --gateway-id <igw-id>
set_default_route() {
  if ! aws ec2 create-route --route-table-id "$1" --destination-cidr-block 0.0.0.0/0 "$2" "$3" \
      >/dev/null 2>&1; then
    aws ec2 replace-route --route-table-id "$1" --destination-cidr-block 0.0.0.0/0 "$2" "$3"
  fi
  log "Route table $1: 0.0.0.0/0 -> $3"
}

associate() {
  local rt="$1" subnet="$2" current
  current="$(q aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$subnet" \
    --query 'RouteTables[0].RouteTableId' --output text)"
  if [[ "$current" == "$rt" ]]; then
    return
  elif [[ -n "$current" ]]; then
    die "subnet $subnet is already associated with route table $current"
  fi
  aws ec2 associate-route-table --route-table-id "$rt" --subnet-id "$subnet" >/dev/null
  log "Associated $subnet with $rt"
}

rt_public="$(ensure_route_table "$RT_PUBLIC_NAME")"
set_default_route "$rt_public" --gateway-id "$igw_id"
associate "$rt_public" "$pub_a"
associate "$rt_public" "$pub_b"

rt_private="$(ensure_route_table "$RT_PRIVATE_NAME")"
associate "$rt_private" "$priv_a"
associate "$rt_private" "$priv_b"

# --- Summary -----------------------------------------------------------------
cat <<EOF

VPC            $vpc_id  ($VPC_CIDR)
public-a       $pub_a   ($CIDR_PUBLIC_A, $AZ_A)
public-b       $pub_b   ($CIDR_PUBLIC_B, $AZ_B)
private-a      $priv_a  ($CIDR_PRIVATE_A, $AZ_A)
private-b      $priv_b  ($CIDR_PRIVATE_B, $AZ_B)
IGW            $igw_id
public RT      $rt_public  (0.0.0.0/0 -> IGW)
private RT     $rt_private (0.0.0.0/0 -> NAT only while infra/nat.sh up)
EOF
