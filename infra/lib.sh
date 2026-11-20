#!/usr/bin/env bash
# Shared names and helpers for the infra/NN-*.sh scripts. Sourced, never run directly.
# Every resource name here comes from docs/ARCHITECTURE.md §3.5. Change it there first.
# shellcheck disable=SC2034  # the variables are used by the scripts that source this file

export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_PAGER=""

PROJECT="taskflow"
OWNER_TAG="M4"
GITHUB_REPO="AmarWaqar-TSKLI/taskflow-devops"
IAM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/iam"

# Network (ARCHITECTURE §4)
VPC_NAME="taskflow-vpc"
VPC_CIDR="10.0.0.0/16"
AZ_A="us-east-1a"
AZ_B="us-east-1b"
SUBNET_PUBLIC_A="taskflow-public-a";   CIDR_PUBLIC_A="10.0.1.0/24"
SUBNET_PUBLIC_B="taskflow-public-b";   CIDR_PUBLIC_B="10.0.2.0/24"
SUBNET_PRIVATE_A="taskflow-private-a"; CIDR_PRIVATE_A="10.0.11.0/24"
SUBNET_PRIVATE_B="taskflow-private-b"; CIDR_PRIVATE_B="10.0.12.0/24"
IGW_NAME="taskflow-igw"
NAT_NAME="taskflow-nat"
NAT_EIP_NAME="taskflow-nat-eip"
RT_PUBLIC_NAME="taskflow-public-rt"
RT_PRIVATE_NAME="taskflow-private-rt"

# Security groups
SG_ALB="taskflow-alb-sg"
SG_APP="taskflow-app-sg"
SG_DB="taskflow-db-sg"

# IAM
OIDC_HOST="token.actions.githubusercontent.com"
ROLE_CI="taskflow-github-ci-role"
ROLE_DEPLOY="taskflow-github-deploy-role"
ROLE_EC2="taskflow-ec2-role"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# Checks we are logged in and sets ACCOUNT_ID.
require_aws() {
  command -v aws >/dev/null || die "aws CLI v2 is not installed"
  ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)" \
    || die "not logged in to AWS. Run: aws login --profile taskflow && export AWS_PROFILE=taskflow"
  log "AWS account $ACCOUNT_ID, region $AWS_REGION, caller $(aws sts get-caller-identity --query Arn --output text)"
}

# Runs an AWS CLI query and prints an empty string instead of "None" when nothing matched.
q() {
  local out
  out="$("$@")"
  [[ "$out" == "None" ]] && out=""
  printf '%s' "$out"
}

# --tag-specifications value for EC2 create calls: tag_spec <resource-type> <name>
tag_spec() {
  printf 'ResourceType=%s,Tags=[{Key=Name,Value=%s},{Key=Project,Value=%s},{Key=Owner,Value=%s}]' \
    "$1" "$2" "$PROJECT" "$OWNER_TAG"
}

# Looks up the VPC by its Name tag. Prints its ID, or nothing.
find_vpc_id() {
  q aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$VPC_NAME" \
    --query 'Vpcs[0].VpcId' --output text
}
