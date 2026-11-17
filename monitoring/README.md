# monitoring

**Owner:** Member 1. What we watch and why: [docs/ARCHITECTURE.md §8](../docs/ARCHITECTURE.md#8-observability).

| File | What |
|------|------|
| `cloudwatch-agent.json` | Agent config: `mem_used_percent`, disk, `append_dimensions` AutoScalingGroupName |
| `dashboard.json` | Export of `taskflow-dashboard` (CloudWatch → Dashboards → Actions → View/edit source) |
| `alarms.md` | Each alarm: metric, threshold, period, why, how we tested it |
