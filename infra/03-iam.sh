#!/usr/bin/env bash
# M4-03 + M4-04: GitHub OIDC provider and the three least-privilege roles:
#   taskflow-github-ci-role      stage 11: push images to the two ECR repos
#   taskflow-github-deploy-role  stage 12 + rollback: set the image tag in SSM, refresh the ASG
#   taskflow-ec2-role            instances: pull images, read tag + DB secret, logs/metrics, Session Manager
# Policies live in infra/iam/*.json with {{ACCOUNT_ID}} filled in at apply time.
# Safe to re-run: existing roles get their trust and inline policies overwritten from the files.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

require_aws
TAGS=("Key=Project,Value=$PROJECT" "Key=Owner,Value=$OWNER_TAG")

render() { sed "s/{{ACCOUNT_ID}}/$ACCOUNT_ID/g" "$IAM_DIR/$1"; }

# --- GitHub OIDC identity provider ----------------------------------------------
oidc_arn="arn:aws:iam::$ACCOUNT_ID:oidc-provider/$OIDC_HOST"
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$oidc_arn" >/dev/null 2>&1; then
  log "OIDC provider exists: $oidc_arn"
else
  log "Creating OIDC provider for $OIDC_HOST"
  aws iam create-open-id-connect-provider --url "https://$OIDC_HOST" \
    --client-id-list sts.amazonaws.com --tags "${TAGS[@]}" >/dev/null
fi

# ensure_role <name> <description> <trust-file> <permissions-file>
ensure_role() {
  local name="$1" desc="$2" trust="$3" perms="$4"
  if aws iam get-role --role-name "$name" >/dev/null 2>&1; then
    log "Role exists, updating trust policy: $name"
    aws iam update-assume-role-policy --role-name "$name" --policy-document "$(render "$trust")"
  else
    log "Creating role $name"
    aws iam create-role --role-name "$name" --description "$desc" \
      --assume-role-policy-document "$(render "$trust")" --tags "${TAGS[@]}" >/dev/null
  fi
  aws iam put-role-policy --role-name "$name" --policy-name "$name-permissions" \
    --policy-document "$(render "$perms")"
  log "  inline policy $name-permissions <- iam/$perms"
}

ensure_role "$ROLE_CI" "GitHub Actions stage 11: push images to ECR (main branch only)" \
  github-ci-trust.json github-ci-permissions.json
ensure_role "$ROLE_DEPLOY" "GitHub Actions stage 12 + rollback: SSM image tag + ASG instance refresh (main only)" \
  github-deploy-trust.json github-deploy-permissions.json
ensure_role "$ROLE_EC2" "TaskFlow EC2 instances: ECR pull, tag + DB secret, CloudWatch, Session Manager" \
  ec2-trust.json ec2-permissions.json

for policy in AmazonSSMManagedInstanceCore CloudWatchAgentServerPolicy AmazonEC2ContainerRegistryReadOnly; do
  aws iam attach-role-policy --role-name "$ROLE_EC2" --policy-arn "arn:aws:iam::aws:policy/$policy"
  log "  attached managed policy $policy"
done

# --- Instance profile (what the launch template references) ---------------------
if ! aws iam get-instance-profile --instance-profile-name "$ROLE_EC2" >/dev/null 2>&1; then
  log "Creating instance profile $ROLE_EC2"
  aws iam create-instance-profile --instance-profile-name "$ROLE_EC2" --tags "${TAGS[@]}" >/dev/null
fi
profile_role="$(q aws iam get-instance-profile --instance-profile-name "$ROLE_EC2" \
  --query 'InstanceProfile.Roles[0].RoleName' --output text)"
if [[ -z "$profile_role" ]]; then
  aws iam add-role-to-instance-profile --instance-profile-name "$ROLE_EC2" --role-name "$ROLE_EC2"
  log "  added $ROLE_EC2 to its instance profile"
fi

cat <<EOF

OIDC provider   $oidc_arn
CI role         arn:aws:iam::$ACCOUNT_ID:role/$ROLE_CI
Deploy role     arn:aws:iam::$ACCOUNT_ID:role/$ROLE_DEPLOY
EC2 role        arn:aws:iam::$ACCOUNT_ID:role/$ROLE_EC2 (+ instance profile)
Trust: only repo:$GITHUB_REPO:ref:refs/heads/main can assume the two GitHub roles.
EOF
