#!/usr/bin/env bash
# Runs the same checks as CI stages 3, 4, 6 and 9 locally, for both services:
#   npm ci · npm run lint · npm run format:check · npm test · npm run build (if defined) · docker build
#
# Usage: scripts/build-and-test.sh [--no-docker] [backend|frontend ...]
#   no service names  -> both services
#   --no-docker       -> skip the image builds (e.g. Docker not running)
# Images are tagged taskflow-<service>:local, the names docker-compose.yml uses.
# Exit: 0 everything passed · 1 a step failed (it says which) · 2 bad usage / missing tool
set -Eeuo pipefail

usage() {
  sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
docker_build=1
services=()
for arg in "$@"; do
  case "$arg" in
    --no-docker) docker_build=0 ;;
    backend | frontend) services+=("$arg") ;;
    *) usage ;;
  esac
done
((${#services[@]} > 0)) || services=(backend frontend)

command -v npm >/dev/null || { echo "build-and-test: npm is required (Node 24)" >&2; exit 2; }
if ((docker_build)) && ! docker info >/dev/null 2>&1; then
  echo "build-and-test: Docker is not running (start it, or pass --no-docker)" >&2
  exit 2
fi

current=""
on_error() { echo "✘ build-and-test FAILED at: $current" >&2; }
trap on_error ERR # -E above makes this fire inside step() too

# step <label> <command...>: runs one check and records it.
step() {
  current="$1"
  shift
  echo "▶ $current"
  "$@"
}

has_script() { node -e 'process.exit(require("./package.json").scripts?.[process.argv[1]] ? 0 : 1)' "$1"; }

start=$SECONDS
for svc in "${services[@]}"; do
  dir="$repo_root/services/$svc"
  [[ -f "$dir/package.json" ]] || { echo "✘ $dir/package.json not found" >&2; exit 1; }
  echo "=== $svc"
  cd "$dir"
  step "$svc: npm ci" npm ci --no-audit --no-fund
  step "$svc: lint" npm run lint
  step "$svc: format check" npm run format:check
  step "$svc: unit tests" npm test
  if has_script build; then
    step "$svc: build" npm run build
  fi
  if ((docker_build)); then
    step "$svc: docker build" docker build -t "taskflow-$svc:local" "$dir"
  fi
done

echo "✔ build-and-test passed for: ${services[*]} ($((SECONDS - start))s)"
