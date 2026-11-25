# monitoring

**Owner:** Member 1. What we watch and why: [docs/ARCHITECTURE.md §8](../docs/ARCHITECTURE.md#8-observability).

| File | What |
|------|------|
| `cloudwatch-agent.json` | Agent config: `mem_used_percent`, disk, `append_dimensions` AutoScalingGroupName |
| `dashboard.json` | Export of `taskflow-dashboard` (CloudWatch → Dashboards → Actions → View/edit source) |
| `alarms.md` | Each alarm: metric, threshold, period, why, how we tested it |
| `setup-monitoring.sh` | Idempotent script to upload agent SSM config, create SNS, dashboard, and alarms |

## Provisioning (`M1-10`–`M1-13`)

Sign in to AWS account `627551519533` (`us-east-1`) and ensure `infra/up.sh` has started the ALB, target groups, and ASG, then run:

```bash
ALERT_EMAILS="haseeb@...,hussain@...,shuja@...,amar@..." monitoring/setup-monitoring.sh up
monitoring/setup-monitoring.sh status
```

`setup-monitoring.sh up`:
1. Uploads `monitoring/cloudwatch-agent.json` to SSM `/taskflow/prod/cloudwatch-agent` (`M1-10`).
2. Creates SNS topic `taskflow-alerts` and subscribes team emails (`M1-11`).
3. Creates/updates `taskflow-dashboard` with the live ALB/target group dimensions and writes `monitoring/dashboard.json` (`M1-12`).
4. Creates `taskflow-unhealthy-frontend`, `taskflow-unhealthy-backend`, `taskflow-backend-5xx`, and `taskflow-high-cpu` alarms (`M1-13`).
