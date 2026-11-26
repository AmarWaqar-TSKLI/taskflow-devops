#!/usr/bin/env bash
# M4-07: EC2 user-data for every TaskFlow app instance (Amazon Linux 2023), run once as root at boot.
# Embedded in the launch template taskflow-lt by infra/05-launch-template.sh.
#
# 1. install Docker, the Compose plugin and the CloudWatch agent
# 2. read the image tag (SSM), the compose file (SSM) and the DB secret (Secrets Manager)
# 3. write the instance layout below (env files root-only) and `docker compose up -d`
#
# Instance layout (contract with M2's docker-compose.prod.yml, see ARCHITECTURE §6):
#   /opt/taskflow/docker-compose.prod.yml  from SSM /taskflow/prod/compose_file
#   /opt/taskflow/.env                     IMAGE_TAG, ECR_REGISTRY, AWS_REGION   (compose interpolation)
#   /opt/taskflow/backend.env      (0600)  PORT, APP_VERSION, LOG_LEVEL, DB_HOST..DB_PASSWORD
# Access needed is granted by taskflow-ec2-role. No secret is ever written to the log.
set -euo pipefail
exec > >(tee -a /var/log/taskflow-user-data.log) 2>&1

COMPOSE_VERSION="v2.32.4"
APP_DIR="/opt/taskflow"
PARAM_IMAGE_TAG="/taskflow/prod/image_tag"
PARAM_COMPOSE="/taskflow/prod/compose_file"
PARAM_CW_AGENT="/taskflow/prod/cloudwatch-agent"
DB_SECRET="taskflow/prod/db"

log() { printf '%s [user-data] %s\n' "$(date -u +%FT%TZ)" "$*"; }
trap 'log "FAILED at line $LINENO (exit $?)"' ERR

# --- Instance metadata (IMDSv2 only; the launch template requires tokens) ---------
imds_token="$(curl -fsS -X PUT http://169.254.169.254/latest/api/token \
  -H 'X-aws-ec2-metadata-token-ttl-seconds: 300')"
imds() { curl -fsS -H "X-aws-ec2-metadata-token: $imds_token" "http://169.254.169.254/latest/meta-data/$1"; }
AWS_REGION="$(imds placement/region)"
export AWS_REGION AWS_DEFAULT_REGION="$AWS_REGION"
log "instance $(imds instance-id) in $(imds placement/availability-zone)"

# --- Packages ------------------------------------------------------------------
log "installing docker, jq, cloudwatch agent"
dnf install -y -q docker jq amazon-cloudwatch-agent
systemctl enable --now docker

arch="$(uname -m)"
plugin_dir=/usr/local/lib/docker/cli-plugins
if [[ ! -x "$plugin_dir/docker-compose" ]]; then
  log "installing docker compose $COMPOSE_VERSION ($arch)"
  base="https://github.com/docker/compose/releases/download/$COMPOSE_VERSION"
  mkdir -p "$plugin_dir"
  curl -fsSL --retry 3 -o "$plugin_dir/docker-compose" "$base/docker-compose-linux-$arch"
  expected="$(curl -fsSL --retry 3 "$base/docker-compose-linux-$arch.sha256" | awk '{print $1}')"
  echo "$expected  $plugin_dir/docker-compose" | sha256sum -c -
  chmod 0755 "$plugin_dir/docker-compose"
fi
docker compose version

# --- CloudWatch agent (memory/disk metrics; config owned by M1, stored in SSM) ------
if aws ssm get-parameter --name "$PARAM_CW_AGENT" >/dev/null 2>&1; then
  /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config -m ec2 -s -c "ssm:$PARAM_CW_AGENT"
  log "cloudwatch agent started with $PARAM_CW_AGENT"
else
  log "WARNING: $PARAM_CW_AGENT not found, cloudwatch agent not started"
fi

# --- What to run -----------------------------------------------------------------
image_tag="$(aws ssm get-parameter --name "$PARAM_IMAGE_TAG" --query Parameter.Value --output text)"
if [[ "$image_tag" == "none" ]]; then
  log "no image deployed yet ($PARAM_IMAGE_TAG = none); host is ready, nothing to start"
  exit 0
fi
account_id="$(aws sts get-caller-identity --query Account --output text)"
registry="$account_id.dkr.ecr.$AWS_REGION.amazonaws.com"

install -d -m 0755 "$APP_DIR"
aws ssm get-parameter --name "$PARAM_COMPOSE" --query Parameter.Value --output text \
  > "$APP_DIR/docker-compose.prod.yml"

cat > "$APP_DIR/.env" <<EOF
IMAGE_TAG=$image_tag
ECR_REGISTRY=$registry
AWS_REGION=$AWS_REGION
EOF

# backend.env holds the DB password: create it root-only before writing anything into it.
install -m 0600 /dev/null "$APP_DIR/backend.env"
aws secretsmanager get-secret-value --secret-id "$DB_SECRET" --query SecretString --output text \
  | jq -r --arg v "$image_tag" '
      "PORT=3000",
      "APP_VERSION=\($v)",
      "LOG_LEVEL=info",
      "DB_HOST=\(.host)",
      "DB_PORT=\(.port)",
      "DB_NAME=\(.dbname)",
      "DB_USER=\(.username)",
      "DB_PASSWORD=\(.password)"' > "$APP_DIR/backend.env"
log "wrote $APP_DIR/.env and $APP_DIR/backend.env (0600) for $image_tag"

# --- Start ---------------------------------------------------------------------------
aws ecr get-login-password | docker login --username AWS --password-stdin "$registry"
cd "$APP_DIR"
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
log "started TaskFlow $image_tag"
