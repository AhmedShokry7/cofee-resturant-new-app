// Checks the push of the app end to end.
//
// The push has two halves that fail for different reasons, so both are
// checked separately:
//
//   1. The in-app half. The database writes the notification, the running app
//      is told about it over Realtime, and the badge on the bell updates.
//      This is checked by joining the channel of a customer and waiting for
//      the event of a notification that is written while the channel is open.
//
//   2. The delivery half. The database hands the notification to the
//      send-push Edge Function, which sends it to Firebase Cloud Messaging.
//      This is checked by reading engagement.push_deliveries after the same
//      notification was written.
//
// The script writes one test notification, waits for both halves and cleans
// up afterwards. It never touches a real customer.
//
// Usage:
//   node tools/check_push.mjs [customer.email]
import { readFileSync } from 'node:fs';

const env = {};
for (const line of readFileSync('.env', 'utf8').split(/\r?\n/)) {
  const m = line.match(/^\s*([A-Z_]+)\s*=\s*(.*)$/);
  if (m) env[m[1]] = m[2].trim().replace(/^["']|["']$/g, '');
}

const url = env.SUPABASE_URL;
const publishableKey = env.SUPABASE_PUBLISHABLE_KEY;
const accessToken = env.SUPABASE_ACCESS_TOKEN;
const projectRef = env.SUPABASE_PROJECT_REF || (url ?? '').split('//')[1]?.split('.')[0];

if (!url || !publishableKey || !accessToken || !projectRef) {
  console.error('.env is missing SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, SUPABASE_ACCESS_TOKEN or SUPABASE_PROJECT_REF.');
  process.exit(2);
}

const email = process.argv[2] ?? 'customer.a@test.local';
const password = env.TEST_USER_PASSWORD ?? 'TestPass!2345';
const testToken = `check-push-${Date.now()}`;

function log(step, ok, detail = '') {
  const mark = ok ? 'OK  ' : 'FAIL';
  console.log(`${mark} ${step}${detail ? ` - ${detail}` : ''}`);
}

async function sql(query) {
  const response = await fetch(`https://api.supabase.com/v1/projects/${projectRef}/database/query`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query }),
  });
  const text = await response.text();
  if (!response.ok) throw new Error(`SQL ${response.status}: ${text}`);
  return text ? JSON.parse(text) : [];
}

// --- 1. a customer with a session ------------------------------------------
const signIn = await fetch(`${url}/auth/v1/token?grant_type=password`, {
  method: 'POST',
  headers: { apikey: publishableKey, 'Content-Type': 'application/json' },
  body: JSON.stringify({ email, password }),
});
if (!signIn.ok) {
  console.error(`Could not sign in as ${email}: ${signIn.status} ${await signIn.text()}`);
  process.exit(2);
}
const session = await signIn.json();
const userId = session.user.id;
log('signed in', true, email);

// --- 2. the token of a device, the way the app registers it ----------------
const registered = await fetch(`${url}/rest/v1/rpc/register_device_token`, {
  method: 'POST',
  headers: {
    apikey: publishableKey,
    Authorization: `Bearer ${session.access_token}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    p_platform: 'android',
    p_token: testToken,
    p_app_version: 'check-push',
    p_device_name: 'check-push',
    p_locale: 'ar',
  }),
});
log('device token registered', registered.ok, registered.ok ? '' : `${registered.status} ${await registered.text()}`);

const preferences = await fetch(`${url}/rest/v1/rpc/set_push_preferences`, {
  method: 'POST',
  headers: {
    apikey: publishableKey,
    Authorization: `Bearer ${session.access_token}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({ p_push_enabled: true }),
});
log('push enabled for the customer', preferences.ok, preferences.ok ? '' : await preferences.text());

// --- 3. the realtime channel of the customer -------------------------------
const channel = `notifications:${userId}`;
const socketUrl = `${url.replace(/^http/, 'ws')}/realtime/v1/websocket?apikey=${publishableKey}&vsn=1.0.0`;
const socket = new WebSocket(socketUrl);
let joined = false;
const realtimeEvent = new Promise((resolve) => {
  const timer = setTimeout(() => resolve(null), 25000);
  socket.addEventListener('open', () => {
    socket.send(
      JSON.stringify({
        topic: `realtime:${channel}`,
        event: 'phx_join',
        payload: {
          config: {
            broadcast: { ack: false, self: false },
            presence: { key: '' },
            postgres_changes: [
              {
                event: 'INSERT',
                schema: 'engagement',
                table: 'notifications',
                filter: `user_id=eq.${userId}`,
              },
            ],
          },
          access_token: session.access_token,
        },
        ref: '1',
      }),
    );
  });
  socket.addEventListener('message', (event) => {
    const message = JSON.parse(event.data);
    if (message.event === 'system' && message.payload?.status === 'ok') {
      // The channel only receives the changes that happen after the
      // subscription is confirmed, so the notification is written after this.
      joined = true;
    }
    if (message.event === 'postgres_changes') {
      clearTimeout(timer);
      resolve(message.payload?.data?.record ?? null);
    }
  });
  socket.addEventListener('error', () => {
    clearTimeout(timer);
    resolve(null);
  });
});

for (let attempt = 0; attempt < 50 && !joined; attempt++) {
  await new Promise((resolve) => setTimeout(resolve, 200));
}
log('realtime channel joined', joined, joined ? channel : 'no confirmation in 10s');

// --- 4. a notification, the way the triggers write it ----------------------
const notificationId = crypto.randomUUID();
await sql(`
  insert into engagement.notifications
    (user_id, type, title_ar, title_en, body_ar, body_en, payload, dedupe_key)
  values (
    '${userId}', 'system',
    'فحص الإشعارات', 'Push check',
    'رسالة فحص', 'Check message',
    '{}'::jsonb, 'check:' || gen_random_uuid()::text
  );
`);

// --- 5. what the two halves answer ---------------------------------------
const record = await realtimeEvent;
log('realtime reached the running app', record !== null, record ? `title_ar=${record.title_ar}` : 'no event in 25s');
socket.close();

let delivery = null;
for (let attempt = 0; attempt < 10; attempt++) {
  await new Promise((resolve) => setTimeout(resolve, 2000));
  const rows = await sql(
    `select status, platform, error, provider_message_id from engagement.push_deliveries where user_id = '${userId}' order by created_at desc limit 1;`,
  );
  if (rows.length) {
    delivery = rows[0];
    break;
  }
}
if (!delivery) {
  log('the Edge Function received the notification', false, 'no delivery row in 20s');
} else if (delivery.status === 'sent') {
  log('the Edge Function sent the push', true, `message ${delivery.provider_message_id}`);
} else if (delivery.error === 'service_account_not_configured') {
  log('the Edge Function received the notification', true, 'but FCM has no service account yet');
  console.log('');
  console.log('  The last step needs a service account of the Firebase project:');
  console.log('  Firebase console -> Project settings -> Service accounts -> Generate new private key');
  console.log('  then: .\\tools\\setup_push.ps1 -KeyFile "<the downloaded json>"');
} else {
  log('the Edge Function received the notification', true, `${delivery.status}: ${delivery.error ?? ''}`);
}

// --- 6. cleanup -----------------------------------------------------------
await sql(`delete from engagement.push_deliveries where user_id = '${userId}' and platform = 'android';`);
await sql(`delete from engagement.notifications where user_id = '${userId}' and dedupe_key like 'check:%';`);
await sql(`delete from engagement.device_tokens where token = '${testToken}';`);
await sql(`delete from engagement.notification_preferences where user_id = '${userId}';`);
log('test data removed', true);

// --- 7. the devices that are ready to receive a push ----------------------
const devices = await sql(`
  select t.user_id,
         p.email,
         t.platform,
         t.locale,
         coalesce(pref.push_enabled, false) as push_enabled,
         t.last_seen_at
    from engagement.device_tokens t
    left join identity.profiles p on p.id = t.user_id
    left join engagement.notification_preferences pref on pref.user_id = t.user_id
   order by t.last_seen_at desc;
`);
if (!devices.length) {
  console.log('');
  console.log('No device has registered a token yet. The app registers one when it');
  console.log('starts and the customer allows the notifications.');
} else {
  console.log('');
  console.log('Devices that can receive a push:');
  for (const device of devices) {
    console.log(
      `  ${device.email ?? device.user_id} - ${device.platform} - ${device.locale ?? '-'} - push ${
        device.push_enabled ? 'on' : 'off'
      }`,
    );
    if (!device.push_enabled) {
      console.log('    push is off: the customer has to allow the notifications in the app');
    }
  }
}
