import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 500 }, // High concurrency
    { duration: '1m', target: 500 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<50'], // Heartbeats must be very fast to ingest
    http_req_failed: ['rate<0.001'], // Ultra-low failure tolerance
  },
};

export default function () {
  const payload = JSON.stringify({
    citizen_id: `citizen_${__VU}`,
    timestamp: new Date().toISOString(),
    location: {
      lat: 34.0522 + (Math.random() * 0.01),
      lng: -118.2437 + (Math.random() * 0.01)
    },
    battery_status: Math.floor(Math.random() * 100)
  });

  const params = {
    headers: { 'Content-Type': 'application/json' },
  };

  const res = http.post('http://localhost:3000/api/heartbeats', payload, params);
  
  check(res, {
    'ingested successfully': (r) => r.status === 202 || r.status === 200,
  });
  
  sleep(1);
}
