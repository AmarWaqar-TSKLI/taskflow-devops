#!/usr/bin/env bash
# M4-06: the two SSM parameters that drive deployments (free, standard tier).
#   /taskflow/prod/image_tag           tag the instances run; user-data reads it at boot, deploy.sh sets it
#   /taskflow/prod/previous_image_tag  tag before the last deploy; used for auto-rollback
# Created with the placeholder "none" (no image has been pushed yet). Existing values are NEVER
# overwritten, because after the first deploy they hold the live version.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

require_aws

for name in "$PARAM_IMAGE_TAG" "$PARAM_PREVIOUS_TAG"; do
  if value="$(aws ssm get-parameter --name "$name" --query Parameter.Value --output text 2>/dev/null)"; then
    log "$name exists = $value (left unchanged)"
  else
    aws ssm put-parameter --name "$name" --type String --value none \
      --description "TaskFlow image tag (set by the deploy job)" \
      --tags "Key=Project,Value=$PROJECT" "Key=Owner,Value=$OWNER_TAG" >/dev/null
    log "$name created = none"
  fi
done
