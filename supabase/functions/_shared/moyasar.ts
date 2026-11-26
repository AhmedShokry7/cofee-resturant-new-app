export function env(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing environment variable ${name}`);
  return value;
}

export function moyasarSecretKey(): string {
  const mode = env("MOYASAR_MODE");
  const key = env("MOYASAR_SECRET_KEY");
  if (mode === "sandbox" && !key.startsWith("sk_test_")) {
    throw new Error("MOYASAR_MODE=sandbox requires a Moyasar test secret key");
  }
  if (mode === "production" && !key.startsWith("sk_live_")) {
    throw new Error(
      "MOYASAR_MODE=production requires a Moyasar live secret key",
    );
  }
  if (mode !== "sandbox" && mode !== "production") {
    throw new Error("MOYASAR_MODE must be sandbox or production");
  }
  return key;
}

export function moyasarPaymentUrl(paymentId: string): string {
  return `https://api.moyasar.com/v1/payments/${encodeURIComponent(paymentId)}`;
}

export async function moyasarRequest(path: string): Promise<any> {
  const credentials = btoa(`${moyasarSecretKey()}:`);
  const response = await fetch(moyasarPaymentUrl(path), {
    headers: { "Authorization": `Basic ${credentials}` },
  });
  const text = await response.text();
  let json: any;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = null;
  }
  if (!response.ok) {
    // Keep provider response bodies out of logs and client-visible exceptions.
    throw new Error(`Moyasar API returned ${response.status}`);
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
  const response = await fetch(`${supabaseUrl()}/auth/v1/user`, {
    headers: {
      "Authorization": authHeader,
      "apikey": Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? serviceRoleKey(),
    },
  });
  if (!response.ok) return null;
  const user = await response.json();
  return user?.id ? { id: user.id, email: user.email } : null;
}

function serviceHeaders(): Record<string, string> {
  const key = serviceRoleKey();
  return {
    "apikey": key,
    "Authorization": `Bearer ${key}`,
    "Content-Type": "application/json",
  };
}

export async function serviceFetch(
  path: string,
  init: RequestInit = {},
): Promise<any> {
  const response = await fetch(`${supabaseUrl()}/rest/v1${path}`, {
    ...init,
    headers: { ...serviceHeaders(), ...(init.headers ?? {}) },
  });
  const text = await response.text();
  let json: any = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = null;
  }
  if (!response.ok) {
    throw new Error(
      `Supabase returned ${response.status} (${json?.code ?? "unknown"}): ${
        json?.message ?? "request failed"
      }`,
    );
  }
  return json;
}

export function amountInMinorUnits(amount: unknown, currency: string): number {
  const value = Number(amount);
  const code = currency.toUpperCase();
  const decimals =
    ["BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND"].includes(code) ? 3 : [
        "BIF",
        "CLP",
        "DJF",
        "GNF",
        "ISK",
        "JPY",
        "KMF",
        "KRW",
        "PYG",
        "RWF",
        "UGX",
        "VND",
        "VUV",
        "XAF",
        "XOF",
        "XPF",
      ].includes(code)
      ? 0
      : 2;
  if (!Number.isFinite(value) || value <= 0) return 0;
  return Math.round(value * (10 ** decimals));
}
