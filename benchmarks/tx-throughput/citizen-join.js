import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  scenarios: {
    burst: {
      executor: 'per-vu-iterations',
      vus: 100,
      iterations: 50,
      maxDuration: '30s',
    },
  },
  thresholds: {
    http_req_duration: ['p(99)<500'], // 99% of requests below 500ms under burst
    http_req_failed: ['rate<0.05'],   // Max 5% failure under burst load
  },
};

export default function () {
  const payload = JSON.stringify({
    citizen_pubkey: `citizen_${__VU}_${__ITER}`,
    city_id: 'test_city_001',
    signature: 'mock_sig'
  });

  const params = {
    headers: { 'Content-Type': 'application/json' },
  };

  const res = http.post('http://localhost:3000/api/citizens/join', payload, params);
  
  check(res, {
    'joined successfully': (r) => r.status === 200 || r.status === 201,
  });
  
  // Minimal sleep to simulate burst
  sleep(Math.random() * 0.1);
}
