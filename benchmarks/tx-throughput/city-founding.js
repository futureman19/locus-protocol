import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '10s', target: 50 },  // Ramp up
    { duration: '30s', target: 50 },  // Plateau
    { duration: '10s', target: 0 },   // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<200'], // 95% of requests must complete below 200ms
    http_req_failed: ['rate<0.01'],   // Error rate < 1%
  },
};

export default function () {
  const payload = JSON.stringify({
    name: `City_${__ITER}`,
    latitude: 34.0522 + (Math.random() * 0.1),
    longitude: -118.2437 + (Math.random() * 0.1),
    founder: `pubkey_${__VU}_${__ITER}`,
    stake: 1000
  });

  const params = {
    headers: { 'Content-Type': 'application/json' },
  };

  const res = http.post('http://localhost:3000/api/cities', payload, params);
  
  check(res, {
    'is status 201 or 200': (r) => r.status === 201 || r.status === 200,
  });
  
  sleep(1);
}
