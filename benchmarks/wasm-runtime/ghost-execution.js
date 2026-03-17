import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '15s', target: 200 },
    { duration: '30s', target: 200 },
    { duration: '15s', target: 0 },
  ],
  thresholds: {
    // WASM execution should be fast. p95 < 150ms ensures cold starts aren't dominating.
    http_req_duration: ['p(95)<150'],
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  // Simulating an invocation of a Ghost WASM runtime instance via the API/RPC
  const payload = JSON.stringify({
    ghost_id: `ghost_contract_${Math.floor(Math.random() * 100)}`,
    method: 'execute_merchant_logic',
    args: {
      amount: 10,
      user: `user_${__VU}`
    }
  });

  const params = {
    headers: { 'Content-Type': 'application/json' },
  };

  const res = http.post('http://localhost:3000/api/ghosts/invoke', payload, params);
  
  check(res, {
    'invoked successfully': (r) => r.status === 200,
  });
  
  sleep(1);
}
