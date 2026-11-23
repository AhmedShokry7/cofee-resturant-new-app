// Brevo HTTP client for transactional email.
// The API key is read only by an Edge Function from Supabase Function Secrets.

export type BrevoEmail = {
  from: string;
  to: string;
  subject: string;
  text: string;
  html: string;
  replyTo?: string | null;
  headers?: Record<string, string>;
};

export type BrevoResult = {
  ok: boolean;
  id?: string;
  error?: string;
};

const BREVO_URL = "https://api.brevo.com/v3/smtp/email";

function mailbox(value: string, defaultName = ""): { name?: string; email: string } | null {
  const angleMatch = value.trim().match(/^(.*?)<\s*([^<>\s]+@[^<>\s]+)\s*>$/);
  if (angleMatch) {
    const name = angleMatch[1].trim().replace(/^"|"$/g, "");
    return { ...(name ? { name } : {}), email: angleMatch[2] };
  }
  const email = value.trim();
  if (!/^[^<>\s@]+@[^<>\s@]+\.[^<>\s@]+$/.test(email)) return null;
  return { ...(defaultName ? { name: defaultName } : {}), email };
}

function describe(text: string): string {
  const trimmed = text.trim();
  if (!trimmed) return "no response body";
  try {
    const parsed = JSON.parse(trimmed);
    const code = typeof parsed?.code === "string" ? parsed.code : "";
    const message = typeof parsed?.message === "string" ? parsed.message : "";
    return ([code, message].filter(Boolean).join(": ") || trimmed).slice(0, 200);
  } catch {
    return trimmed.slice(0, 200);
  }
}

/// Sends one message. Errors never include the API key or request headers.
export async function sendEmail(
  apiKey: string,
  email: BrevoEmail,
  fetchImpl: typeof fetch = fetch,
): Promise<BrevoResult> {
  const sender = mailbox(email.from, "New Coffee");
  const recipient = mailbox(email.to);
  const replyTo = email.replyTo ? mailbox(email.replyTo) : null;
  if (!sender || !recipient || (email.replyTo && !replyTo)) {
    return { ok: false, error: "brevo: invalid sender or recipient address" };
  }

  const body: Record<string, unknown> = {
    sender,
    to: [recipient],
    subject: email.subject,
    textContent: email.text,
    htmlContent: email.html,
  };
  if (replyTo) body.replyTo = replyTo;
  if (email.headers && Object.keys(email.headers).length > 0) {
    body.headers = email.headers;
  }

  let response: Response;
  try {
    response = await fetchImpl(BREVO_URL, {
      method: "POST",
      headers: {
        "api-key": apiKey,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify(body),
    });
  } catch (error) {
    return {
      ok: false,
      error: error instanceof Error ? error.message.slice(0, 200) : "network_error",
    };
  }

  const text = await response.text();
  if (response.ok) {
    let json: any = null;
    try {
      json = text ? JSON.parse(text) : null;
    } catch {
      json = null;
    }
    return { ok: true, id: json?.messageId };
  }
  return { ok: false, error: `brevo ${response.status}: ${describe(text)}` };
}
