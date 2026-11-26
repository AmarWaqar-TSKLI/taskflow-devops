import http from "k6/http";
import { check, sleep } from "k6";

const baseUrl = (__ENV.BASE_URL || "http://localhost:8080").replace(/\/+$/, "");
const peakVus = Number(__ENV.PEAK_VUS || 40);
const rampUp = __ENV.RAMP_UP || "1m";
const hold = __ENV.HOLD || "5m";
const rampDown = __ENV.RAMP_DOWN || "1m";

export const options = {
  stages: [
    { duration: rampUp, target: peakVus },
    { duration: hold, target: peakVus },
    { duration: rampDown, target: 0 },
  ],
  thresholds: {
    http_req_failed: ["rate<0.05"],
    http_req_duration: ["p(95)<2000"],
  },
};

export default function () {
  const uiRes = http.get(`${baseUrl}/`);
  check(uiRes, { "GET / is 200": (r) => r.status === 200 });

  const listRes = http.get(`${baseUrl}/api/tasks`);
  check(listRes, { "GET /api/tasks is 200": (r) => r.status === 200 });

  const createRes = http.post(
    `${baseUrl}/api/tasks`,
    JSON.stringify({ title: `k6-load-${__VU}-${__ITER}` }),
    { headers: { "Content-Type": "application/json" } },
  );
  const createdOk = check(createRes, {
    "POST /api/tasks is 201": (r) => r.status === 201,
  });

  if (createdOk) {
    const id = createRes.json("id");
    if (id) {
      const delRes = http.del(`${baseUrl}/api/tasks/${id}`);
      check(delRes, {
        "DELETE /api/tasks/:id is 204": (r) => r.status === 204,
      });
    }
  }

  sleep(0.2);
}
