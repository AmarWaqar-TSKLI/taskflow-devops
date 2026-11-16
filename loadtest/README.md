# loadtest

**Owner:** Member 1 (writes the script; the team runs the demo together).

`load.js` — k6 script that ramps traffic against the ALB until average CPU crosses the ASG target
(50%), holds it long enough for scale-out, then ramps down so we can show scale-in.

```bash
k6 run -e BASE_URL=http://<alb-dns-name> loadtest/load.js
```

Evidence to capture (D-04): k6 summary · ASG activity history (launch + terminate) · CloudWatch CPU graph
and instance count over the same window. Scale-in takes ~15 min after load stops: wait for it.
