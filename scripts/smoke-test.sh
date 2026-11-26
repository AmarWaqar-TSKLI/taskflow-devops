#!/usr/bin/env bash
# Post-deploy smoke test (pipeline stage 12, rollback.yml, or by hand against Compose).
#
# Usage: scripts/smoke-test.sh <base_url>
#   e.g. scripts/smoke-test.sh http://localhost:8080
#        scripts/smoke-test.sh "$ALB_URL"
# Env:   EXPECT_VERSION  if set, /api/health must report exactly this version (e.g. v1.0.42)
#        HEALTHCHECK_RETRIES / HEALTHCHECK_DELAY / HEALTHCHECK_TIMEOUT  passed to healthcheck.sh
# Checks, in order: frontend /health · backend /api/health (+ version) · UI page loads ·
#   create a task · read it back · delete it · it is gone.
# Exit: 0 all checks passed · 1 a check failed · 2 bad usage / missing tool
set -euo pipefail

usage() {
  sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}
[[ $# -eq 1 && "$1" =~ ^https?:// ]] || usage
for tool in curl jq; do
  command -v "$tool" >/dev/null || { echo "smoke-test: $tool is required" >&2; exit 2; }
done

base="${1%/}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
timeout="${HEALTHCHECK_TIMEOUT:-5}"
body_file="$(mktemp)"
task_id=""

pass() { printf '  ✔ %s\n' "$*"; }
fail() {
  printf '  ✘ %s\n' "$*" >&2
  echo "SMOKE TEST FAILED against $base" >&2
  exit 1
}

# request <METHOD> <path> [json-body]: sets $status, response body in $body_file.
request() {
  local method="$1" path="$2" data="${3:-}"
  local args=(-sS -o "$body_file" -w '%{http_code}' --max-time "$timeout" -X "$method")
  [[ -n "$data" ]] && args+=(-H 'Content-Type: application/json' --data "$data")
  status="$(curl "${args[@]}" "$base$path" 2>/dev/null)" || status="000"
}

cleanup() {
  # If we failed between create and delete, don't leave the test task behind.
  if [[ -n "$task_id" ]]; then
    curl -sS -o /dev/null --max-time "$timeout" -X DELETE "$base/api/tasks/$task_id" 2>/dev/null || true
  fi
  rm -f "$body_file"
}
trap cleanup EXIT

echo "Smoke test against $base"

echo "1. Health endpoints"
"$script_dir/healthcheck.sh" "$base/health" "$base/api/health" | sed 's/^/  /' ||
  fail "health endpoints not healthy"

request GET /api/health
[[ "$status" == 200 ]] || fail "GET /api/health returned $status"
[[ "$(jq -r '.status // empty' "$body_file" 2>/dev/null)" == "ok" ]] ||
  fail "GET /api/health body is not {\"status\":\"ok\",...}: $(head -c 200 "$body_file")"
version="$(jq -r '.version // "unknown"' "$body_file")"
if [[ -n "${EXPECT_VERSION:-}" && "$version" != "$EXPECT_VERSION" ]]; then
  fail "backend reports version $version, expected $EXPECT_VERSION"
fi
pass "backend status ok, version $version"

echo "2. UI"
request GET /
[[ "$status" == 200 ]] || fail "GET / returned $status"
grep -qiE '<!doctype html|<html' "$body_file" || fail "GET / did not return an HTML page"
pass "GET / serves the app page"

echo "3. Tasks API round trip"
title="smoke-test $(date -u +%Y%m%dT%H%M%SZ)-$RANDOM"
request POST /api/tasks "$(jq -cn --arg t "$title" '{title: $t}')"
[[ "$status" == 201 ]] || fail "POST /api/tasks returned $status: $(head -c 200 "$body_file")"
task_id="$(jq -r '.id // empty' "$body_file")"
[[ -n "$task_id" ]] || fail "POST /api/tasks response has no id"
pass "created task $task_id"

request GET /api/tasks
[[ "$status" == 200 ]] || fail "GET /api/tasks returned $status"
jq -e --arg id "$task_id" --arg t "$title" \
  'any(.[]; (.id | tostring) == $id and .title == $t)' "$body_file" >/dev/null ||
  fail "task $task_id not found in GET /api/tasks"
pass "read task $task_id back"

request DELETE "/api/tasks/$task_id"
[[ "$status" == 204 ]] || fail "DELETE /api/tasks/$task_id returned $status"
deleted_id="$task_id"
task_id=""
pass "deleted task $deleted_id"

request GET /api/tasks
[[ "$status" == 200 ]] || fail "GET /api/tasks returned $status"
jq -e --arg id "$deleted_id" 'all(.[]; (.id | tostring) != $id)' "$body_file" >/dev/null ||
  fail "task $deleted_id still listed after DELETE"
pass "task $deleted_id is gone"

echo "SMOKE TEST PASSED against $base (version $version)"
