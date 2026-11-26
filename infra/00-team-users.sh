#!/usr/bin/env bash
# M4-00: one IAM user per teammate, all in the group taskflow-team.
#   PowerUserAccess     build/operate everything except IAM (ECR, CloudWatch, SNS, EC2, RDS, ...)
#   IAMReadOnlyAccess   see roles and trust policies (viva, screenshots), change nothing
#   IAMUserChangePassword + iam/team-self-mfa.json   set own password and own MFA device
# No access keys are created: console only. Console access is enabled separately with a one-time
# password and "must reset at next sign-in"
# (aws iam create-login-profile --user-name <u> --password <temp> --password-reset-required).
# Temporary passwords go to each member privately, never into git.
# Safe to re-run.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

GROUP="taskflow-team"
USERS=(hussain haseeb shuja)

require_aws

# Account password policy: applies to every console user.
aws iam update-account-password-policy --minimum-password-length 12 \
  --require-uppercase-characters --require-lowercase-characters --require-numbers --require-symbols \
  --allow-users-to-change-password --password-reuse-prevention 3
log "Password policy: min 12 chars, upper + lower + number + symbol, no reuse of last 3"

if ! aws iam get-group --group-name "$GROUP" >/dev/null 2>&1; then
  log "Creating group $GROUP"
  aws iam create-group --group-name "$GROUP" >/dev/null
fi
for policy in PowerUserAccess IAMReadOnlyAccess IAMUserChangePassword; do
  aws iam attach-group-policy --group-name "$GROUP" --policy-arn "arn:aws:iam::aws:policy/$policy"
done
aws iam put-group-policy --group-name "$GROUP" --policy-name taskflow-team-self-mfa \
  --policy-document "file://$IAM_DIR/team-self-mfa.json"
log "Group $GROUP: PowerUserAccess, IAMReadOnlyAccess, IAMUserChangePassword, self-managed MFA"

for user in "${USERS[@]}"; do
  if aws iam get-user --user-name "$user" >/dev/null 2>&1; then
    log "User exists: $user"
  else
    log "Creating user $user"
    aws iam create-user --user-name "$user" \
      --tags "Key=Project,Value=$PROJECT" "Key=Owner,Value=$OWNER_TAG" >/dev/null
  fi
  aws iam add-user-to-group --user-name "$user" --group-name "$GROUP"
done

cat <<EOF

Users in $GROUP: ${USERS[*]}
Sign-in URL: https://$ACCOUNT_ID.signin.aws.amazon.com/console
Console access: create-login-profile with a one-time password + --password-reset-required.
Each member then: sign in, set a new password, add an MFA device (top-right menu -> Security credentials).
EOF
