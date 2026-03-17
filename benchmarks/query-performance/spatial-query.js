import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '10s', target: 100 },
    { duration: '30s', target: 100 },
    { duration: '10s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(90)<100', 'p(95)<200', 'p(99)<500'], 
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  // Random bounding box or lat/lng around Los Angeles
  const lat = 34.0522 + (Math.random() * 2 - 1);
  const lng = -118.2437 + (Math.random() * 2 - 1);
  const radius = 50; // km

  const res = http.get(`http://localhost:3000/api/cities/nearby?lat=${lat}&lng=${lng}&radius=${radius}`);
  
  check(res, {
    'is status 200': (r) => r.status === 200,
  });
  
  sleep(0.5);
}
