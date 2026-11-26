# loadtest

**Owner:** Member 1 (writes the script; the team runs the demo together).

`load.js` — k6 script that ramps traffic against the ALB until average CPU crosses the ASG target
(50%), holds it long enough for scale-out, then ramps down so we can show scale-in.

## Run against AWS ALB (`D-04`)

```bash
k6 run -e BASE_URL=http://<alb-dns-name> loadtest/load.js
```

Or using Docker (no local `k6` install required):

```bash
docker run --rm -i grafana/k6 run -e BASE_URL=http://<alb-dns-name> - < loadtest/load.js
```

## Tunable options (env vars)

| Variable | Default | Purpose |
|---|---|---|
| `BASE_URL` | `http://localhost:8080` | Target URL (local Compose or AWS ALB) |
| `PEAK_VUS` | `40` | Virtual users at peak load |
| `RAMP_UP` | `1m` | Ramp-up duration |
| `HOLD` | `5m` | Sustain duration to trigger ASG scale-out |
| `RAMP_DOWN` | `1m` | Ramp-down duration before scale-in observation |

Quick local smoke check (5 VUs, 15s total):

```bash
docker run --rm -i --add-host=host.docker.internal:host-gateway grafana/k6 run \
  -e BASE_URL=http://host.docker.internal:8080 \
  -e PEAK_VUS=5 -e RAMP_UP=5s -e HOLD=5s -e RAMP_DOWN=5s - < loadtest/load.js
```

Evidence to capture (D-04): k6 summary · ASG activity history (launch + terminate) · CloudWatch CPU graph
and instance count over the same window. Scale-in takes ~15 min after load stops: wait for it.
