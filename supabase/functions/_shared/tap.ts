// supabase/functions/_shared/tap.ts
export function env(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing environment variable ${name}`);
  return value;
}

export function tapSecretKey(): string {
  const mode = env("TAP_ENV");
  const key = env("TAP_SECRET_KEY");
  if (mode === "sandbox" && !key.startsWith("sk_test_")) {
    throw new Error("TAP_ENV=sandbox requires a Tap test secret key");
  }
  if (mode === "production" && !key.startsWith("sk_live_")) {
    throw new Error("TAP_ENV=production requires a Tap live secret key");
  }
  if (mode !== "sandbox" && mode !== "production") {
    throw new Error("TAP_ENV must be sandbox or production");
  }
  return key;
}

export function tapBaseUrl(): string {
  // Tap selects test/live processing from the secret API key. Keep the API
  // hostname fixed so a deployment cannot redirect credentials elsewhere.
  return "https://api.tap.company/v2";
}

export async function tapRequest(
  path: string,
  init: RequestInit = {},
): Promise<any> {
  const response = await fetch(`${tapBaseUrl()}${path}`, {
    ...init,
    headers: {
      "Authorization": `Bearer ${tapSecretKey()}`,
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    },
  });
  const text = await response.text();
  let json: any = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = { raw: text };
  }
  if (!response.ok) {
    throw new Error(`Tap API ${response.status}: ${JSON.stringify(json)}`);
  }
  return json;
}

export function supabaseUrl(): string {
  return env("SUPABASE_URL");
}

export function serviceRoleKey(): string {
  return env("SUPABASE_SERVICE_ROLE_KEY");
}

export async function getUserFromRequest(
  req: Request,
): Promise<{ id: string; email?: string } | null> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) return null;
  const token = authHeader.slice(7);
  const response = await fetch(`${supabaseUrl()}/auth/v1/user`, {
    headers: {
      "Authorization": `Bearer ${token}`,
      "apikey": Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? serviceRoleKey(),
    },
  });
  if (!response.ok) return null;
  const user = await response.json();
  return user?.id ? { id: user.id, email: user.email } : null;
}

export function serviceClientHeaders(): Record<string, string> {
  return {
    "apikey": serviceRoleKey(),
    "Authorization": `Bearer ${serviceRoleKey()}`,
    "Content-Type": "application/json",
  };
}

export async function serviceFetch(
  path: string,
  init: RequestInit = {},
): Promise<any> {
  const response = await fetch(`${supabaseUrl()}/rest/v1${path}`, {
    ...init,
    headers: {
      ...serviceClientHeaders(),
      ...(init.headers ?? {}),
    },
  });
  const text = await response.text();
  let json: any = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = text;
  }
  if (!response.ok) {
    throw new Error(`Supabase ${response.status}: ${JSON.stringify(json)}`);
  }
  return json;
}

export async function verifyTapWebhookHash(
  signedMessage: string,
  headers: Headers,
  secretKey: string,
): Promise<boolean> {
  const posted = headers.get("hashstring") ?? headers.get("hash");
  if (!posted || !/^[0-9a-f]{64}$/i.test(posted)) return false;
  const expected = await hmacSha256Hex(signedMessage, secretKey);
  let difference = 0;
  for (let i = 0; i < expected.length; i++) {
    difference |= expected.charCodeAt(i) ^ posted.toLowerCase().charCodeAt(i);
  }
  return difference === 0;
}

export function hmacSha256Hex(
  message: string,
  secret: string,
): Promise<string> {
  return crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  ).then((key) =>
    crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message))
  ).then((signature) =>
    Array.from(new Uint8Array(signature))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("")
  );
}
