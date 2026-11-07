// k6 load test: realistic API mix for signed-in couples.
// NEVER point this at production without an approved plan.
//
//   docker run --rm -i --network couples-verify_edge -e BASE=http://web:8080/api/v1 \
//     grafana/k6:0.57.0 run - < deploy/loadtest/api-mix.js
//
// The target must allow many registrations from one IP (verify.env sets high
// RATE_LIMIT_* values); real rate limits are tested separately.
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Rate } from 'k6/metrics';

const BASE = __ENV.BASE || 'http://127.0.0.1:8088/api/v1';
const COUPLES = Number(__ENV.COUPLES || 25);
const json = { headers: { 'Content-Type': 'application/json', Accept: 'application/json' } };

const listLatency = new Trend('list_latency', true);
const writeLatency = new Trend('write_latency', true);
const errors = new Rate('errors');

export const options = {
  scenarios: {
    // Ramp to ~2× the 10k-couple evening peak estimate (≈95 req/s, cost-model.md).
    couples: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 20 },
        { duration: '1m', target: 50 },
        { duration: '1m', target: 50 },
        { duration: '20s', target: 0 },
      ],
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    'http_req_duration{kind:read}': ['p(95)<500'],
    'http_req_duration{kind:write}': ['p(95)<800'],
  },
};

function auth(token) {
  return { headers: { ...json.headers, Authorization: `Bearer ${token}` } };
}

// Create COUPLES couples (2 users each) once, return their tokens.
export function setup() {
  const tokens = [];
  const run = Date.now();
  for (let i = 0; i < COUPLES; i++) {
    const reg = (n) => http.post(`${BASE}/auth/register`, JSON.stringify({
      name: `Load ${n}`, email: `load-${run}-${i}-${n}@example.test`,
      password: 'load-test-pw-1', password_confirmation: 'load-test-pw-1',
    }), json).json('data.token');
    const a = reg('a');
    const b = reg('b');
    const invite = http.post(`${BASE}/couple`, null, auth(a)).json('data.couple.invite_code');
    http.post(`${BASE}/couple/join`, JSON.stringify({ invite_code: invite }), auth(b));
    for (let m = 0; m < 10; m++) {
      http.post(`${BASE}/memories`, JSON.stringify({ title: `Memory ${m}`, memory_date: '2026-10-01' }), auth(a));
      http.post(`${BASE}/dates`, JSON.stringify({ title: `Date ${m}`, scheduled_at: '2026-12-01T19:00:00Z' }), auth(b));
    }
    tokens.push(a, b);
  }
  return { tokens };
}

export default function (data) {
  const token = data.tokens[(__VU - 1) % data.tokens.length];
  const p = auth(token);
  const read = (url) => {
    const r = http.get(`${BASE}${url}`, { ...p, tags: { kind: 'read' } });
    listLatency.add(r.timings.duration);
    errors.add(r.status !== 200);
    check(r, { [`GET ${url} 200`]: (res) => res.status === 200 });
  };

  // App open: profile, couple, lists, plan.
  read('/me');
  read('/couple');
  read('/memories');
  read('/memories/timeline');
  read('/dates');
  read('/couple/subscription');
  read('/memories/protection');

  // ~1 in 4 iterations writes something (plan a date, comment).
  if (Math.random() < 0.25) {
    const w = http.post(`${BASE}/dates`, JSON.stringify({ title: 'Dinner', scheduled_at: '2026-12-24T19:00:00Z' }), { ...p, tags: { kind: 'write' } });
    writeLatency.add(w.timings.duration);
    errors.add(w.status !== 201);
    check(w, { 'POST /dates 201': (res) => res.status === 201 });
  }

  sleep(1 + Math.random() * 2); // think time
}
