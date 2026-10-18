// supabase/functions/_shared/tap.ts
export function env(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing environment variable ${name}`);
  return value;
}

export function tapSecretKey(): string {
  return env("TAP_SECRET_KEY");
}

export function tapBaseUrl(): string {
  return Deno.env.get("TAP_BASE_URL") ?? "https://api.tap.company/v2";
}

export async function tapRequest(path: string, init: RequestInit = {}): Promise<any> {
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

export async function getUserFromRequest(req: Request): Promise<{ id: string; email?: string } | null> {
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

export async function serviceFetch(path: string, init: RequestInit = {}): Promise<any> {
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

export function verifyTapWebhookHash(body: string, headers: Headers, secretKey: string): boolean {
  const posted = headers.get("hashstring") ?? headers.get("hash");
  if (!posted) return false;
  // The exact hashstring input is built by the caller from the parsed charge.
  // This helper only compares a precomputed value.
  return false;
}

export function hmacSha256Hex(message: string, secret: string): Promise<string> {
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
