// k6 load test — production smoke & performance gate
// Usage: k6 run --env TARGET_URL=https://todoapp-kps.akawatmor.com load-test.js

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export const options = {
  stages: [
    { duration: '15s', target: 10 },   // ramp up
    { duration: '30s', target: 20 },   // sustained load
    { duration: '15s', target: 0 },    // ramp down
  ],
  thresholds: {
    http_req_failed:   ['rate<0.05'],   // <5% HTTP errors
    http_req_duration: ['p(95)<2000'],  // p95 < 2 s
    errors:            ['rate<0.05'],   // <5% check failures
  },
};

const BASE = (__ENV.TARGET_URL || 'https://todoapp-kps.akawatmor.com').replace(/\/$/, '');
const PATHS = ['/healthz', '/readyz', '/api/v1/meta'];

export default function () {
  const path = PATHS[Math.floor(Math.random() * PATHS.length)];
  const res = http.get(BASE + path, {
    headers: { 'User-Agent': 'k6-load-test/1.0' },
    timeout: '10s',
  });

  const ok = check(res, {
    'status 200':        (r) => r.status === 200,
    'duration < 2000ms': (r) => r.timings.duration < 2000,
  });

  errorRate.add(!ok);
  sleep(0.5);
}
