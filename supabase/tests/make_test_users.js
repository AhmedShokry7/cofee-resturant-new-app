// Creates real Supabase Auth users via the admin API, then assigns staff roles.
// Real users matter: the acceptance tests must run as `authenticated`, not
// as postgres, or they prove nothing about RLS.
const https = require('https');

const SB = process.env.SBURL;
const KEY = process.env.SBKEY;

function req(method, path, body) {
  return new Promise((resolve, reject) => {
    const u = new global.URL(path, SB);
    const data = body ? JSON.stringify(body) : null;
    const r = https.request({
      method, hostname: u.hostname, path: u.pathname + u.search,
      headers: {
        apikey: KEY, Authorization: `Bearer ${KEY}`,
        'Content-Type': 'application/json', ...(data ? { 'Content-Length': Buffer.byteLength(data) } : {}),
      },
    }, res => {
      let b = '';
      res.on('data', d => (b += d));
      res.on('end', () => { try { resolve(JSON.parse(b)); } catch { resolve(b); } });
    });
    r.on('error', reject);
    if (data) r.write(data);
    r.end();
  });
}

(async () => {
  const people = [
    { email: 'customer.a@test.local',  name: 'Customer A' },
    { email: 'customer.b@test.local',  name: 'Customer B' },
    { email: 'owner@test.local',       name: 'Owner' },
    { email: 'manager.main@test.local',name: 'Main Manager' },
    { email: 'manager.jed@test.local', name: 'Jeddah Manager' },
    { email: 'cashier.main@test.local',name: 'Main Cashier' },
    { email: 'suspended@test.local',   name: 'Suspended Staff' },
  ];

  const out = {};
  for (const p of people) {
    let r = await req('POST', '/auth/v1/admin/users', {
      email: p.email, password: 'TestPass!2345', email_confirm: true,
      user_metadata: { full_name: p.name },
    });
    if (r.id) { out[p.email] = r.id; continue; }

    // already exists -> find it
    const list = await req('GET', '/auth/v1/admin/users?per_page=200');
    const found = (list.users || []).find(u => u.email === p.email);
    if (found) out[p.email] = found.id;
    else console.error(`  FAILED to create ${p.email}:`, JSON.stringify(r).slice(0, 200));
  }

  console.log(JSON.stringify(out, null, 2));
  require('fs').writeFileSync(
    require('path').join(__dirname, 'users.json'), JSON.stringify(out, null, 2));
})();