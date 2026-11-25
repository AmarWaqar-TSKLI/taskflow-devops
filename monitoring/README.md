# monitoring

**Owner:** Member 1. What we watch and why: [docs/ARCHITECTURE.md §8](../docs/ARCHITECTURE.md#8-observability).

| File | What |
|------|------|
| `cloudwatch-agent.json` | Agent config: `mem_used_percent`, disk, `append_dimensions` AutoScalingGroupName |
| `dashboard.json` | Export of `taskflow-dashboard` (CloudWatch → Dashboards → Actions → View/edit source) |
| `alarms.md` | Each alarm: metric, threshold, period, why, how we tested it |

## CloudWatch Agent SSM parameter (`M1-10`)

`infra/user-data.sh` fetches the agent configuration from SSM `/taskflow/prod/cloudwatch-agent` at boot.
Upload or update it in AWS account `627551519533` (`us-east-1`):

```bash
aws ssm put-parameter \
  --name /taskflow/prod/cloudwatch-agent \
  --type String \
  --overwrite \
  --value file://monitoring/cloudwatch-agent.json \
  --region us-east-1
```
