// supabase/functions/_shared/resend.ts
//
// Resend HTTP client.
//
// Resend is the mail provider: it owns the connection to the receiving
// providers, the SPF/DKIM checks and the bounce handling. The database never
// talks to it directly and the app never sees its key: only an Edge Function
// reads RESEND_API_KEY from the function secrets, so the credential stays on
// the server.
//
//   supabase secrets set RESEND_API_KEY='re_xxx'
//
// The API is one JSON POST, so no package is needed and no SMTP socket is
// opened, which the edge runtime cannot do anyway.

/// One message handed to Resend.
export type ResendEmail = {
  /// The verified sender, for example "New Coffee <orders@example.com>".
  from: string;
  /// A single recipient. A campaign is one row per customer, so a bulk send
  /// is many calls of this function, never one call with many addresses.
  to: string;
  subject: string;
  /// Plain text for the readers that never load HTML, and for the forwarding
  /// agents that strip it.
  text: string;
  html: string;
  /// Where a reply goes, or null to let the provider default stand.
  replyTo?: string | null;
  /// Extra headers, used for the unsubscribe links.
  headers?: Record<string, string>;
};

/// The outcome of one send attempt.
export type ResendResult = {
  ok: boolean;
  /// The id Resend gives the message; it is what support matches a report to.
  id?: string;
  error?: string;
};

/// The address of the API.
const RESEND_URL = "https://api.resend.com/emails";

/// Sends one email through Resend.
///
/// A failure is returned instead of thrown: one refused address must not stop
/// the rest of a campaign, and the caller writes the reason to the delivery
/// log. The key is never part of the returned error text.
export async function sendEmail(
  apiKey: string,
  email: ResendEmail,
  fetchImpl: typeof fetch = fetch,
): Promise<ResendResult> {
  const body: Record<string, unknown> = {
    from: email.from,
    to: [email.to],
    subject: email.subject,
    text: email.text,
    html: email.html,
  };
  if (email.replyTo) body.reply_to = email.replyTo;
  if (email.headers && Object.keys(email.headers).length > 0) {
    body.headers = email.headers;
  }

  let response: Response;
  try {
    response = await fetchImpl(RESEND_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });
  } catch (error) {
    // A network failure says nothing about the address, so the message keeps
    // the reason short and the caller can retry the same row later.
    return {
      ok: false,
      error: error instanceof Error ? error.message : String(error),
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
    return { ok: true, id: json?.id };
  }

  // The text of the answer is copied into the delivery log an admin reads, so
  // only a short description of it stays: a provider page or a stack trace
  // would bury the one line that matters.
  return {
    ok: false,
    error: `resend ${response.status}: ${describe(text)}`,
  };
}

/// The shortest part of a provider answer that is safe to store.
function describe(text: string): string {
  const trimmed = text.trim();
  if (!trimmed) return "no response body";
  try {
    const parsed = JSON.parse(trimmed);
    const message = typeof parsed?.message === "string" ? parsed.message : "";
    const name = typeof parsed?.name === "string" ? parsed.name : "";
    const safe = [name, message].filter(Boolean).join(": ");
    return (safe || trimmed).slice(0, 200);
  } catch {
    return trimmed.slice(0, 200);
  }
}
