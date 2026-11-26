#!/usr/bin/env bash
# Checks that every URL answers 2xx, retrying while the service comes up.
#
# Usage: scripts/healthcheck.sh [-r retries] [-d delay_s] [-t timeout_s] <url> [<url>...]
#   -r  attempts per URL                 (default $HEALTHCHECK_RETRIES or 10)
#   -d  seconds between attempts         (default $HEALTHCHECK_DELAY or 3)
#   -t  timeout per request, in seconds  (default $HEALTHCHECK_TIMEOUT or 5)
# Exit: 0 all healthy · 1 at least one URL never answered 2xx · 2 bad usage
# Example: scripts/healthcheck.sh http://localhost:8080/health http://localhost:8080/api/health
set -euo pipefail

usage() {
  sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

retries="${HEALTHCHECK_RETRIES:-10}"
delay="${HEALTHCHECK_DELAY:-3}"
timeout="${HEALTHCHECK_TIMEOUT:-5}"

while getopts ':r:d:t:h' opt; do
  case "$opt" in
    r) retries="$OPTARG" ;;
    d) delay="$OPTARG" ;;
    t) timeout="$OPTARG" ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))
[[ $# -ge 1 ]] || usage
for n in "$retries" "$delay" "$timeout"; do
  [[ "$n" =~ ^[0-9]+$ ]] || { echo "healthcheck: '$n' is not a whole number" >&2; usage; }
done
((retries >= 1 && timeout >= 1)) || { echo "healthcheck: retries and timeout must be >= 1" >&2; usage; }
command -v curl >/dev/null || { echo "healthcheck: curl is required" >&2; exit 2; }

# check_url <url>: retries until a 2xx answer; prints one result line, returns 0 or 1.
check_url() {
  local url="$1" attempt code
  for ((attempt = 1; attempt <= retries; attempt++)); do
    code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time "$timeout" "$url" 2>/dev/null)" || code="000"
    if [[ "$code" =~ ^2[0-9][0-9]$ ]]; then
      printf 'OK    %s (HTTP %s, attempt %d/%d)\n' "$url" "$code" "$attempt" "$retries"
      return 0
    fi
    ((attempt < retries)) && sleep "$delay"
  done
  printf 'FAIL  %s (last answer: %s after %d attempts)\n' "$url" \
    "$([[ "$code" == "000" ]] && echo "no response" || echo "HTTP $code")" "$retries"
  return 1
}

failed=0
for url in "$@"; do
  check_url "$url" || failed=$((failed + 1))
done

if ((failed > 0)); then
  echo "healthcheck: $failed of $# URL(s) unhealthy" >&2
  exit 1
fi
echo "healthcheck: all $# URL(s) healthy"
