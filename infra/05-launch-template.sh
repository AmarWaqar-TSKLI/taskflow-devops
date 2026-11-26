#!/usr/bin/env bash
# M4-08: launch template taskflow-lt for the ASG.
#   Amazon Linux 2023 (latest, from AWS's public SSM parameter), t3.micro, NO key pair,
#   IMDSv2 required, taskflow-ec2-role instance profile, taskflow-app-sg, encrypted gp3 root,
#   user-data = infra/user-data.sh.
# Re-running creates a new template version (e.g. after editing user-data.sh) and makes it the
# default, so the next ASG instance refresh picks it up.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

require_aws
vpc_id="$(find_vpc_id)"
[[ -n "$vpc_id" ]] || die "$VPC_NAME not found. Run infra/01-network.sh first"
app_sg="$(q aws ec2 describe-security-groups --filters "Name=group-name,Values=$SG_APP" \
  "Name=vpc-id,Values=$vpc_id" --query 'SecurityGroups[0].GroupId' --output text)"
[[ -n "$app_sg" ]] || die "$SG_APP not found. Run infra/02-security-groups.sh first"

ami="$(aws ssm get-parameter --name "$AMI_PARAM" --query Parameter.Value --output text)"
user_data="$(base64 -w0 "$(dirname "$0")/user-data.sh")"

data="$(jq -nc --arg ami "$ami" --arg type "$INSTANCE_TYPE" --arg sg "$app_sg" \
  --arg profile "$ROLE_EC2" --arg ud "$user_data" --arg project "$PROJECT" --arg owner "$OWNER_TAG" '{
  ImageId: $ami,
  InstanceType: $type,
  IamInstanceProfile: {Name: $profile},
  SecurityGroupIds: [$sg],
  UserData: $ud,
  MetadataOptions: {HttpTokens: "required", HttpEndpoint: "enabled", HttpPutResponseHopLimit: 2},
  BlockDeviceMappings: [{DeviceName: "/dev/xvda",
    Ebs: {VolumeSize: 8, VolumeType: "gp3", Encrypted: true, DeleteOnTermination: true}}],
  TagSpecifications: [
    {ResourceType: "instance", Tags: [{Key: "Name", Value: "taskflow-app"},
      {Key: "Project", Value: $project}, {Key: "Owner", Value: $owner}]},
    {ResourceType: "volume", Tags: [{Key: "Name", Value: "taskflow-app"},
      {Key: "Project", Value: $project}, {Key: "Owner", Value: $owner}]}]
}')"

if aws ec2 describe-launch-templates --launch-template-names "$LT_NAME" >/dev/null 2>&1; then
  version="$(aws ec2 create-launch-template-version --launch-template-name "$LT_NAME" \
    --version-description "updated $(date -u +%FT%TZ)" --launch-template-data "$data" \
    --query LaunchTemplateVersion.VersionNumber --output text)"
  aws ec2 modify-launch-template --launch-template-name "$LT_NAME" --default-version "$version" >/dev/null
  log "Launch template $LT_NAME: new version $version is now the default"
else
  aws ec2 create-launch-template --launch-template-name "$LT_NAME" \
    --version-description "initial" --launch-template-data "$data" \
    --tag-specifications "$(tag_spec launch-template "$LT_NAME")" >/dev/null
  log "Created launch template $LT_NAME (version 1)"
fi

cat <<EOF

$LT_NAME   AMI $ami ($AMI_PARAM)
           $INSTANCE_TYPE, no key pair, IMDSv2 required (hop limit 2)
           profile $ROLE_EC2, SG $SG_APP ($app_sg), 8 GB gp3 encrypted
           user-data: infra/user-data.sh
EOF
