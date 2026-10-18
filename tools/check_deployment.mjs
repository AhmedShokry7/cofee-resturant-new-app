// Verifies the backend the app depends on is actually deployed.
//
// Everything here is read-only: it calls each endpoint with an empty body and
// reports whether it answered. Two things it deliberately does NOT do:
//
//   * Probe Edge Functions through /rest/v1/rpc/. Edge functions are not
//     PostgREST functions, so that route returns PGRST202 for them whether or
//     not they exist. They must be probed at /functions/v1/<name>, where a
//     deployed function answers 400/401/405 and an absent one answers 404
//     "Requested function was not found".
//
//   * Treat PGRST202 on a SQL function as proof of absence. PostgREST reports
//     PGRST202 both for "no such function" and for "no EXECUTE grant for this
//     role", so several functions here are granted to `authenticated` only and
//     look missing from anon.
//
// Run: node tools/check_deployment.mjs
import { readFileSync } from 'node:fs';

const env = {};
for (const line of readFileSync('.env', 'utf8').split(/\r?\n/)) {
  const m = line.match(/^\s*([A-Z_]+)\s*=\s*(.*)$/);
  if (m) env[m[1]] = m[2].trim();
}
const url = env.SUPABASE_URL;
const key = env.SUPABASE_SERVICE_ROLE_KEY || env.SUPABASE_PUBLISHABLE_KEY;
if (!url || !key) {
  console.error('.env has no SUPABASE_URL / key. Copy .env.example and fill it in.');
  process.exit(2);
}

// SQL functions: a non-PGRST202 answer means "present, and we got a real
// rejection", which is all we can learn without valid arguments.
const SQL = [
  'validate_coupon_for_cart',
  'delivery_zones_for_branch',
  'get_featured',
  'coupon_availability',
  'coupon_scope',
  'resolve_delivery_zone',
  'coupon_line_breakdown',
];

const EDGE = [
  'tap-create-charge',
  'tap-verify-charge',
  'tap-delete-card',
  'tap-webhook',
  'tap-tokenize-card',
];

const present = [];
const missing = [];

// SQL functions: check pg_proc directly via the Management API is not available
// from the client, so we probe each function. A 404 PGRST202 means "not found";
// anything else (400, 401, 403, 42501) means it exists but rejected our args.
const SQL_ARGS = {
  'validate_coupon_for_cart': { p_branch_id: null, p_code: 'X', p_lines: [] },
  'delivery_zones_for_branch': { p_branch_id: null },
  'get_featured': { p_branch_id: null, p_limit: 1 },
  'coupon_availability': {},
  'coupon_scope': { p_code: 'X' },
  'resolve_delivery_zone': { p_branch_id: null, p_lat: 0, p_lng: 0 },
  'coupon_line_breakdown': { p_branch_id: null, p_code: 'X', p_lines: [] },
};

for (const name of SQL) {
  const res = await fetch(`${url}/rest/v1/rpc/${name}`, {
    method: 'POST',
    headers: { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(SQL_ARGS[name] || {}),
  });
  const text = (await res.text()).replace(/\s+/g, ' ');
  const absent = /PGRST202|Could not find the function/i.test(text);
  (absent ? missing : present).push(`sql  ${name}`);
  console.log(`${absent ? 'MISSING ' : 'ok      '} sql  ${name.padEnd(24)} HTTP ${res.status}`);
}

for (const name of EDGE) {
  const res = await fetch(`${url}/functions/v1/${name}`, {
    method: 'POST',
    headers: { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: '{}',
  });
  const text = (await res.text()).replace(/\s+/g, ' ');
  const absent = res.status === 404 && /not found/i.test(text);
  (absent ? missing : present).push(`edge ${name}`);
  console.log(`${absent ? 'MISSING ' : 'ok      '} edge ${name.padEnd(24)} HTTP ${res.status}`);
}

console.log(`\n${present.length} present, ${missing.length} missing`);
if (missing.length) {
  console.log('\nMissing ط£آ¢أ¢â€ڑآ¬أ¢â‚¬â€Œ apply the migrations and deploy the functions:');
  for (const m of missing) console.log(`  ${m}`);
  process.exit(1);
}