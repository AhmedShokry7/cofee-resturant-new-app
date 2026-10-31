// supabase/functions/_shared/fcm.ts
//
// FCM HTTP v1 client.
//
// The legacy FCM API, the one that authenticated with the "server key" from
// the Firebase console, was switched off. Delivery therefore goes through the
// HTTP v1 API, which authenticates with a Google service account: the
// function signs a short lived JWT with the private key of the service
// account and exchanges it for an access token.
//
// The service account is a function secret, never a database row and never
// something the app can read:
//
//   supabase secrets set FIREBASE_SERVICE_ACCOUNT='{"type":"service_account",...}'
//
// The JSON is the key file downloaded from
// Firebase console -> Project settings -> Service accounts -> Generate new
// private key. It contains a private key, so it must never leave the server.

/// The fields of the service account key that are needed to send a message.
export type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

/// The message that is handed to FCM.
export type FcmMessage = {
  title: string;
  body: string;
  /// FCM only accepts string values in the data payload.
  data: Record<string, string>;
  /// A public picture shown next to the message, or null for a text message.
  imageUrl?: string | null;
};

/// The outcome of one delivery attempt.
export type FcmSendResult = {
  ok: boolean;
  messageId?: string;
  error?: string;
  /// True when FCM says the token is not valid any more. The caller then
  /// deletes the token instead of trying again on the next notification.
  invalidToken?: boolean;
};

/// Reads the service account out of the secret, or null when it is missing or
/// malformed.
///
/// A missing service account is a configuration problem, not a crash: the
/// caller records the failure and the customer still sees the notification in
/// the app.
export function parseServiceAccount(raw: string | undefined): ServiceAccount | null {
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw);
    if (
      parsed &&
      typeof parsed.project_id === "string" &&
      typeof parsed.client_email === "string" &&
      typeof parsed.private_key === "string"
    ) {
      return {
        project_id: parsed.project_id,
        client_email: parsed.client_email,
        private_key: parsed.private_key,
      };
    }
    return null;
  } catch {
    return null;
  }
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function base64UrlEncodeText(text: string): string {
  return base64UrlEncode(new TextEncoder().encode(text));
}

/// Imports the PEM private key of the service account.
///
/// The key file of a Google service account is a PKCS#8 PEM, so the header and
/// the footer are stripped, the body is decoded and the result is imported as
/// a PKCS#8 key. The key is only used to sign, never to decrypt.
export async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const binary = Uint8Array.from(atob(body), (char) => char.charCodeAt(0));
  return await crypto.subtle.importKey(
    "pkcs8",
    binary,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

/// Exchanges the service account for a short lived access token.
///
/// The token is valid for an hour, so it is kept in the warm container and
/// reused. A campaign writes one notification row per customer and every row
/// arrives as its own request, so without the cache a thousand customers would
/// mean a thousand JWT exchanges against Google.
const accessTokens = new Map<string, { token: string; expiresAt: number }>();

/// The seconds an access token is refreshed before it really expires.
const TOKEN_REFRESH_MARGIN_SECONDS = 120;

export async function createAccessToken(
  serviceAccount: ServiceAccount,
  now: () => number = Date.now,
): Promise<string> {
  const cached = accessTokens.get(serviceAccount.client_email);
  if (cached && cached.expiresAt > now()) return cached.token;

  const issuedAt = Math.floor(now() / 1000);
  const header = base64UrlEncodeText(
    JSON.stringify({ alg: "RS256", typ: "JWT" }),
  );
  const claims = base64UrlEncodeText(
    JSON.stringify({
      iss: serviceAccount.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: issuedAt,
      exp: issuedAt + 3600,
    }),
  );

  const key = await importPrivateKey(serviceAccount.private_key);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );
  const assertion = `${header}.${claims}.${base64UrlEncode(new Uint8Array(signature))}`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  const text = await response.text();
  if (!response.ok) {
    throw new Error(`Google token endpoint ${response.status}: ${text}`);
  }
  let json: any = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = null;
  }
  if (!json?.access_token) {
    throw new Error("Google token endpoint returned no access token");
  }

  const lifetime = Number.isFinite(json.expires_in) && json.expires_in > 0
    ? Math.floor(json.expires_in)
    : 3600;
  accessTokens.set(serviceAccount.client_email, {
    token: json.access_token as string,
    expiresAt: now() + (lifetime - TOKEN_REFRESH_MARGIN_SECONDS) * 1000,
  });
  return json.access_token as string;
}

/// Forgets every cached access token. Used by the tests.
export function resetAccessTokenCache(): void {
  accessTokens.clear();
}

/// Sends one message to one device token.
///
/// A failure is returned instead of thrown: one broken token must not stop
/// the delivery to the other devices of the same customer.
export async function sendToToken(
  accessToken: string,
  projectId: string,
  token: string,
  message: FcmMessage,
): Promise<FcmSendResult> {
  const imageUrl = message.imageUrl?.trim() || null;
  try {
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: {
              title: message.title,
              body: message.body,
              // The generic image is what Android's own banner reads; the
              // platform block repeats it so the picture survives on the
              // devices that only look at the android settings.
              ...(imageUrl ? { image: imageUrl } : {}),
            },
            data: message.data,
            android: {
              priority: "high",
              notification: {
                channel_id: "default_notification_channel",
                ...(imageUrl ? { image: imageUrl } : {}),
              },
            },
          },
        }),
      },
    );

    const text = await response.text();
    if (response.ok) {
      let json: any = null;
      try {
        json = text ? JSON.parse(text) : null;
      } catch {
        json = null;
      }
      return { ok: true, messageId: json?.name };
    }

    const invalidToken =
      /UNREGISTERED|registration-token-not-registered|INVALID_ARGUMENT/i.test(
        text,
      ) && /token/i.test(text);
    return {
      ok: false,
      invalidToken,
      error: `FCM ${response.status}: ${text}`,
    };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : String(error) };
  }
}
