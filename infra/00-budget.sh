#!/usr/bin/env bash
# M4-00: monthly AWS cost budget with email alerts at 50% and 80% (actual) and 100% (forecast).
# Emails are passed in, not stored in git:
#   BUDGET_EMAILS="a@example.com,b@example.com" [BUDGET_LIMIT=25] infra/00-budget.sh
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

: "${BUDGET_EMAILS:?set BUDGET_EMAILS to a comma-separated list of emails}"
BUDGET_LIMIT="${BUDGET_LIMIT:-25}"
BUDGET_NAME="taskflow-monthly"

require_aws

if aws budgets describe-budget --account-id "$ACCOUNT_ID" --budget-name "$BUDGET_NAME" >/dev/null 2>&1; then
  log "Budget $BUDGET_NAME already exists, leaving it alone"
  exit 0
fi

subscribers="$(jq -nc --arg e "$BUDGET_EMAILS" \
  '[$e | split(",")[] | gsub("\\s"; "") | select(length > 0) | {SubscriptionType: "EMAIL", Address: .}]')"

notifications="$(jq -nc --argjson s "$subscribers" '[
  {Notification: {NotificationType: "ACTUAL",     ComparisonOperator: "GREATER_THAN", Threshold: 50,  ThresholdType: "PERCENTAGE"}, Subscribers: $s},
  {Notification: {NotificationType: "ACTUAL",     ComparisonOperator: "GREATER_THAN", Threshold: 80,  ThresholdType: "PERCENTAGE"}, Subscribers: $s},
  {Notification: {NotificationType: "FORECASTED", ComparisonOperator: "GREATER_THAN", Threshold: 100, ThresholdType: "PERCENTAGE"}, Subscribers: $s}
]')"

budget="$(jq -nc --arg name "$BUDGET_NAME" --arg amt "$BUDGET_LIMIT" \
  '{BudgetName: $name, BudgetLimit: {Amount: $amt, Unit: "USD"}, TimeUnit: "MONTHLY", BudgetType: "COST",
    CostTypes: {IncludeCredit: false}}')"
# IncludeCredit=false: the account runs on Free-plan credits, so net cost stays $0. Excluding credits
# makes the budget track real usage, i.e. how fast we burn the credits.

log "Creating budget $BUDGET_NAME: \$$BUDGET_LIMIT/month"
aws budgets create-budget --account-id "$ACCOUNT_ID" \
  --budget "$budget" --notifications-with-subscribers "$notifications"
log "Done. Alerts go to: $BUDGET_EMAILS"
