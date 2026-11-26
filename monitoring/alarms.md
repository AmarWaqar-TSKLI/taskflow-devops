# CloudWatch Alarms (`M1-13`)

All alarms publish to SNS topic `taskflow-alerts` in `us-east-1` (`M1-11`), matching [docs/ARCHITECTURE.md §8](../docs/ARCHITECTURE.md#8-observability).

| Alarm name | Namespace / Metric | Dimensions | Condition | Why |
|---|---|---|---|---|
| `taskflow-unhealthy-frontend` | `AWS/ApplicationELB` / `UnHealthyHostCount` | `TargetGroup=taskflow-tg-frontend`, `LoadBalancer=taskflow-alb` | `Maximum >= 1` for 2 × 60s periods | Alerts if any frontend container stops answering `GET /health` |
| `taskflow-unhealthy-backend` | `AWS/ApplicationELB` / `UnHealthyHostCount` | `TargetGroup=taskflow-tg-backend`, `LoadBalancer=taskflow-alb` | `Maximum >= 1` for 2 × 60s periods | Alerts if any backend container fails `GET /api/health` |
| `taskflow-backend-5xx` | `AWS/ApplicationELB` / `HTTPCode_Target_5XX_Count` | `TargetGroup=taskflow-tg-backend`, `LoadBalancer=taskflow-alb` | `Sum > 10` for 2 × 60s periods | Detects application/DB outages (used in incident drill `D-07`) |
| `taskflow-high-cpu` | `AWS/EC2` / `CPUUtilization` | `AutoScalingGroupName=taskflow-asg` | `Average > 80%` for 1 × 300s period | Signals sustained saturation near ASG max capacity |

## Setup

Run after `infra/up.sh` creates the ALB, target groups, and ASG:

```bash
ALERT_EMAILS="haseeb@...,hussain@...,shuja@...,amar@..." monitoring/setup-monitoring.sh up
```

## Verification & Deliberate Trigger Tests (`D-07` / `M1-13`)

1. **Test SNS delivery:**
   ```bash
   aws sns publish --topic-arn arn:aws:sns:us-east-1:627551519533:taskflow-alerts \
     --subject "TaskFlow SNS test" --message "Confirming all team subscriptions"
   ```
2. **Trigger `taskflow-backend-5xx` + `taskflow-unhealthy-backend` (deliberate failure `D-07`):**
   - Temporarily remove the `taskflow-app-sg` inbound rule on `taskflow-db-sg` (or stop backend via SSM) and generate >10 requests/min to `/api/tasks` across 2 minutes.
   - Verify alarm transitions to `ALARM` in CloudWatch and SNS email arrives (`docs/evidence/D07-02-alarm-in-alarm.png`, `D07-03-sns-email.png`).
   - Restore the rule and verify alarms return to `OK`.
3. **Quick synthetic state test (optional check per alarm):**
   ```bash
   aws cloudwatch set-alarm-state --alarm-name taskflow-high-cpu \
     --state-value ALARM --state-reason "Testing SNS notification pipeline"
   ```
