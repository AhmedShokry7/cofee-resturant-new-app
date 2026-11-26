const fs = require('fs');
const path = require('path');
const root = process.cwd();
const env = {};
for (const line of fs.readFileSync(path.join(root, '.env'), 'utf8').split(/\r?\n/)) {
  const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
  if (!m) continue;
  let v = m[2];
  if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) v = v.slice(1, -1);
  env[m[1]] = v;
}
const ref = 'webzzasosevzymftgszn';
if (env.SUPABASE_URL !== `https://${ref}.supabase.co`) throw new Error('unexpected SUPABASE_URL');
const token = env.SUPABASE_ACCESS_TOKEN;
if (!token) throw new Error('SUPABASE_ACCESS_TOKEN missing');
const mode = process.argv[2];
(async () => {
  let url, init;
  if (mode === '--project') {
    url = `https://api.supabase.com/v1/projects/${ref}`;
    init = { headers: { Authorization: `Bearer ${token}` } };
  } else {
    const file = process.argv[3];
    if (!file) throw new Error('usage: node .tmp/supabase_query.cjs --sql <file.sql> | --project');
    url = `https://api.supabase.com/v1/projects/${ref}/database/query`;
    init = {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ query: fs.readFileSync(file, 'utf8') }),
    };
  }
  const res = await fetch(url, init);
  const text = await res.text();
  console.log(`HTTP ${res.status} ref ${ref}`);
  console.log(text);
  if (!res.ok) process.exitCode = 1;
})();
