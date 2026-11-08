import http from 'k6/http';
import { check, fail, sleep } from 'k6';

const baseUrl = (__ENV.SUPABASE_URL || '').replace(/\/$/, '');
const anonKey = __ENV.SUPABASE_ANON_KEY || '';

if (!baseUrl || !anonKey) {
  throw new Error('Set SUPABASE_URL and SUPABASE_ANON_KEY for the staging project.');
}
if (__ENV.LOAD_TEST_CONFIRM !== 'staging-only') {
  throw new Error('Refusing to run: set LOAD_TEST_CONFIRM=staging-only after verifying the target is a dedicated staging project.');
}

const stages = (__ENV.K6_STAGES || '1m:10,3m:50,3m:100,1m:0').split(',').map((entry) => {
  const [duration, target] = entry.trim().split(':');
  if (!duration || !target || !/^\d+(\.\d+)?[smh]$/.test(duration) || !/^\d+$/.test(target)) {
    throw new Error(`Invalid K6_STAGES entry: ${entry}. Expected duration:vus, e.g. 1m:25.`);
  }
  return { duration, target: Number(target) };
});

export const options = {
  stages,
  thresholds: {
    checks: ['rate>0.99'],
    http_req_failed: ['rate<0.01'],
    'http_req_duration{endpoint:branches}': ['p(95)<800', 'p(99)<2000'],
    'http_req_duration{endpoint:categories}': ['p(95)<800', 'p(99)<2000'],
  },
};

const headers = {
  apikey: anonKey,
  authorization: `Bearer ${anonKey}`,
};

function readPublicTable(schema, table, endpoint) {
  const response = http.get(`${baseUrl}/rest/v1/${table}?select=id&limit=50`, {
    headers: { ...headers, 'accept-profile': schema },
    tags: { endpoint },
    timeout: '10s',
  });
  check(response, {
    [`${endpoint}: HTTP 200`]: (r) => r.status === 200,
    [`${endpoint}: JSON array`]: (r) => r.headers['Content-Type']?.includes('application/json') && Array.isArray(r.json()),
  });
  if (response.status >= 500) fail(`${endpoint} returned ${response.status}`);
}

export default function () {
  readPublicTable('core', 'branches', 'branches');
  readPublicTable('catalog', 'categories', 'categories');
  sleep(1);
}
