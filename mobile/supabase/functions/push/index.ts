// supabase/functions/push/index.ts
//
// Sends the actual FCM push for every row inserted into `public.notifications`
// (announcements, document-request status changes, report updates — anything
// that lands in a resident's inbox). This is the piece that makes a document
// request update reach the phone even when the app is backgrounded or closed:
// the app's realtime subscription only runs while it's open, FCM doesn't.
//
// Flow:
//   admin changes document_requests.status   (web admin / SQL)
//     -> document_requests_notify_status_change trigger
//        inserts a public.notifications row   (document_requests_full_details.sql)
//          -> Database Webhook on notifications INSERT
//             -> this function -> https://fcm.googleapis.com/v1/...
//
// Deployment and the Database Webhook click-through steps are in
// supabase/PUSH_NOTIFICATIONS_SETUP.md.
//
// Required secret:
//   FIREBASE_SERVICE_ACCOUNT = the single-line JSON of the Firebase service
//                              account key (Firebase console > Project
//                              settings > Service accounts > Generate new
//                              private key).
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically by the
// Supabase Edge Runtime, so they don't need to be set by hand.
//
// Deploy with:  supabase functions deploy push --no-verify-jwt
// (--no-verify-jwt because a Database Webhook can't mint a Supabase user JWT;
// access is instead guarded below by requiring the service-role key header
// that the dashboard adds when you pick "Add auth header with service key".)

// deno-lint-ignore-file no-explicit-any

// VS Code's local TypeScript server doesn't know the Deno / Supabase Edge
// Runtime globals, so it flags every `Deno.*` as "Cannot find name 'Deno'"
// (TS2304). This declares just the surface this file uses so editing stays
// clean locally. At deploy time the REAL `Deno` object is provided by the
// Edge Runtime — this `declare` emits no JS and changes nothing there.
declare const Deno: {
  env: { get(key: string): string | undefined };
  serve(handler: (req: Request) => Response | Promise<Response>): void;
};

interface NotificationRecord {
  id: string;
  user_id: string;
  title: string;
  message: string;
  type: string;
  data: Record<string, unknown> | null;
}

interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE';
  table: string;
  schema: string;
  record: NotificationRecord;
  old_record: NotificationRecord | null;
}

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

// ── tiny base64url + JWT helpers (RS256 via WebCrypto, no dependencies) ──────

function base64UrlEncode(bytes: Uint8Array<ArrayBufferLike>): string {
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64UrlEncodeString(text: string): string {
  return base64UrlEncode(new TextEncoder().encode(text));
}

/** Decodes a PEM private key ("-----BEGIN PRIVATE KEY-----...") to DER bytes. */
function pemToPkcs8(pem: string): Uint8Array {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\\n/g, '\n')
    .replace(/[\r\n\s]/g, '');
  const raw = atob(base64);
  const bytes = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
  return bytes;
}

async function getFcmAccessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = {
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };

  const unsigned =
    `${base64UrlEncodeString(JSON.stringify(header))}.` +
    `${base64UrlEncodeString(JSON.stringify(claims))}`;

  const key = await crypto.subtle.importKey(
    'pkcs8',
    // TS 5.8+ types `keyData` as ArrayBuffer | ArrayBufferView<ArrayBuffer>.
    // `pemToPkcs8` returns Uint8Array<ArrayBufferLike> whose `.buffer` may be
    // the wider ArrayBufferLike (ArrayBuffer | SharedArrayBuffer).
    // `Uint8Array.from(...)` copies into a fresh Uint8Array<ArrayBuffer>,
    // whose `.buffer` is a real ArrayBuffer — accepted both locally and on
    // the Edge Runtime.
    Uint8Array.from(pemToPkcs8(account.private_key)).buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );

  const jwt = `${unsigned}.${base64UrlEncode(new Uint8Array(signature))}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }).toString(),
  });

  const body = await res.json();
  if (!res.ok || !body.access_token) {
    throw new Error(`Google OAuth token exchange failed: ${JSON.stringify(body)}`);
  }
  return body.access_token as string;
}

// ── Supabase REST helper ─────────────────────────────────────────────────────

async function fetchFcmToken(userId: string): Promise<string | null> {
  const url = `${Deno.env.get('SUPABASE_URL')}/rest/v1/profiles` +
    `?id=eq.${encodeURIComponent(userId)}&select=fcm_token`;
  const res = await fetch(url, {
    headers: {
      apikey: Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      Authorization: `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
    },
  });
  if (!res.ok) return null;
  const rows = await res.json();
  const token = Array.isArray(rows) ? rows[0]?.fcm_token : null;
  return typeof token === 'string' && token.length > 0 ? token : null;
}

// ── handler ──────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  // The dashboard's "add auth header with service key" header is the only gate
  // (the function is deployed with --no-verify-jwt). Reject anything else so
  // the public function URL can't be used to spam residents' devices.
  const auth = req.headers.get('Authorization') ?? '';
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  if (!serviceKey || auth !== `Bearer ${serviceKey}`) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  let payload: WebhookPayload;
  try {
    payload = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const record = payload?.record;
  if (!record?.user_id) {
    return new Response(JSON.stringify({ skipped: 'no record' }), { status: 200 });
  }

  const fcmToken = await fetchFcmToken(record.user_id);
  if (!fcmToken) {
    // Resident never granted notification permission, or uninstalled the app.
    // Not an error — the in-app notification row is still there to read.
    return new Response(JSON.stringify({ skipped: 'no fcm_token' }), { status: 200 });
  }

  const rawAccount = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
  if (!rawAccount) {
    return new Response(
      JSON.stringify({ error: 'FIREBASE_SERVICE_ACCOUNT secret is not set' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }
  const account: ServiceAccount = JSON.parse(rawAccount);

  const accessToken = await getFcmAccessToken(account);

  // FCM data payload values must all be strings.
  const data: Record<string, string> = { type: record.type ?? 'system' };
  if (record.data) {
    for (const [k, v] of Object.entries(record.data)) {
      data[k] = typeof v === 'string' ? v : JSON.stringify(v);
    }
  }
  data['notification_id'] = record.id;

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token: fcmToken,
          notification: { title: record.title, body: record.message },
          data,
          android: {
            priority: 'high',
            notification: {
              // Must match the channel PushNotificationService creates
              // (AndroidNotificationChannel 'milaud_default_channel').
              channel_id: 'milaud_default_channel',
              color: '#4C229C',
            },
          },
          apns: { payload: { aps: { sound: 'default', badge: 1 } } },
        },
      }),
    },
  );

  const resBody = await res.json().catch(() => ({}));
  return new Response(JSON.stringify(resBody), {
    status: res.ok ? 200 : res.status,
    headers: { 'Content-Type': 'application/json' },
  });
});

