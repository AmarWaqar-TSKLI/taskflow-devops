# Incident: tasks API down, database unreachable from the app instances

Deliberate failure for demo D-07. We broke one thing and watched how monitoring caught it.

| | |
|---|---|
| Date / time (start → end) | 26 Nov 2026, 19:27:47 → 19:33:14 UTC (alarm cleared 19:42:57) |
| Duration | ~4 min 45 s of failed API requests (19:28:30 → 19:33:14) |
| Impact | The page loaded but showed an error: every `/api/tasks` call returned **500** after a 5 s wait. 556 of our test requests failed. `/api/health` stayed `ok` the whole time |
| Detected by | CloudWatch alarm `taskflow-backend-5xx` (more than 10 target 5xx per minute, 2 periods in a row) → SNS `taskflow-alerts` email |

## Timeline (UTC)
- 19:27:47: the "bad change": the inbound rule on `taskflow-db-sg` (TCP 5432 from `taskflow-app-sg`) was deleted
- 19:28:30: users hit the API. Pooled DB connections had gone idle (30 s idle timeout), so new connections were needed, and they timed out
- 19:32:57: `taskflow-backend-5xx` went to **ALARM** and the SNS email went out
- 19:33:07: diagnosis: health endpoint fine, backend logs full of DB connection timeouts (below)
- 19:33:11: fix: the security-group rule was re-added
- 19:33:14: `GET /api/tasks` returned 200 again
- 19:42:57: alarm back to **OK**

## Diagnosis
- The **CloudWatch dashboard** showed backend 5xx climbing while both target groups stayed healthy. So the
  instances were alive and the problem was behind them.
- **Backend logs** (`/taskflow/backend`, JSON lines):
  `{"level":"error","msg":"unhandled error","error":"Connection terminated due to connection timeout"}` and
  `{"level":"error","msg":"http request","method":"GET","path":"/api/tasks","status":500,"duration_ms":5003.4}`.
  Requests took 5 s, exactly the pool's `connectionTimeoutMillis`, so the DB port was not answering.
- RDS itself showed as `available`, which pointed at the network path. `taskflow-db-sg` had no inbound rule left.

## Root cause
The only rule that lets the app instances reach Postgres was removed. Security groups are stateful, so
connections that were already open kept working for a while. The outage only started once the pool opened new connections.

## Fix
Re-added the inbound rule: TCP 5432 on `taskflow-db-sg` from `taskflow-app-sg`. No restart was needed,
because the pool reconnects on the next request.

## What we'd change to prevent it
- **Infrastructure as code with drift checks:** the rule lives in `infra/02-security-groups.sh`. Running it on a
  schedule, or in CI, would have put it back and shown the drift.
- **A readiness check:** `/api/health` is liveness only (on purpose, so a DB blip doesn't make the ALB pull
  every instance). A separate `/api/ready` that pings the DB would make the dashboard show the cause straight away.
- **Faster alerting:** the alarm needed about 4.5 minutes (two 1-minute periods plus metric delay). One period, or a
  5xx *rate* alarm, would page sooner. That trades off against false alarms during deploys.
