#!/usr/bin/env bash
# M4-00: one IAM user per teammate, all in the group taskflow-team.
#   PowerUserAccess     build/operate everything except IAM (ECR, CloudWatch, SNS, EC2, RDS, ...)
#   IAMReadOnlyAccess   see roles and trust policies (viva, screenshots), change nothing
#   IAMUserChangePassword + iam/team-self-mfa.json   set own password and own MFA device
# No access keys are created: console only. Console passwords are set by Member 4 in the
# IAM console (Users -> <name> -> Security credentials -> Enable console access), never in git or chat.
# Safe to re-run.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

GROUP="taskflow-team"
USERS=(hussain haseeb shuja)

require_aws

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
Next (Member 4, in the console): enable console access for each user with an auto-generated
password + "must reset at next sign-in", and send it to them privately.
Each member then: sign in, set a new password, add an MFA device (top-right menu -> Security credentials).
EOF
