// supabase/functions/_shared/infobip.ts
//
// Infobip SMS v3 client.
//
// Infobip is the messenger for Saudi Arabia: it owns the interconnects, the
// sender ID registration the Saudi registry asks for, and the delivery reports.
// The database never talks to it and the app never sees its key: only an Edge
// Function reads INFOBIP_API_KEY from the function secrets, so the credential
// stays on the server.
//
//   supabase secrets set INFOBIP_API_KEY='xxxx'
//   supabase secrets set INFOBIP_BASE_URL='xxxxxx.infobip.com'
//   supabase secrets set INFOBIP_SENDER='GhaimSohob'
//
// The base URL is the one the Infobip console prints for the account, and it is
// checked below before the key is attached to it: a credential in a header is
// only ever sent to an Infobip host, never to a value someone else typed into
// the environment.
//
// One caveat that decides what a trial account can prove: while an Infobip
// account is in its free trial it only accepts the phone number the
// registration was verified with. A refusal for any other destination is that
// rule, not a bug in this file.

/// The message that is handed to the provider.
export type SmsMessage = {
  /// Destination in E.164 without the leading `+`, which is what the v3 API
  /// puts in `destinations[].to`.
  to: string;
  /// The registered sender ID, or null to let the account default stand.
  sender: string | null;
  text: string;
};

/// The outcome of one send attempt.
export type SmsResult = {
  ok: boolean;
  /// The message id the provider gives back; support matches a report to it.
  messageId?: string;
  error?: string;
};

/// The one endpoint this client knows.
const MESSAGES_PATH = "/sms/3/messages";

/// A host that may be given the API key.
///
/// The account URL Infobip issues always ends in `infobip.com`, so anything
/// else - a scheme, a path, a query, another domain - is refused rather than
/// trusted with a credential.
export function infobipHostOf(raw: string | undefined): string | null {
  const value = (raw ?? "").trim().toLowerCase();
  if (!value) return null;
  const host = value
    .replace(/^https:\/\//, "")
    .replace(/^http:\/\//, "")
    .replace(/\/.*$/, "");
  return /^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*\.infobip\.com$/.test(
      host,
    )
    ? host
    : null;
}

/// The destination in the shape the v3 API asks for.
///
/// A `+` is accepted by the API but the documented body carries bare digits, and
/// anything that is neither is not a phone number the network can route.
export function destinationOf(raw: string | undefined): string | null {
  const digits = (raw ?? "").replace(/[\s+()-]/g, "");
  return /^[0-9]{8,15}$/.test(digits) ? digits : null;
}

/// Sends one SMS through Infobip.
///
/// A failure is returned instead of thrown, because the hook answers GoTrue
/// with a status code and a short reason rather than a stack trace. The key is
/// never part of the returned error text.
export async function sendSms(
  apiKey: string,
  baseUrl: string,
  message: SmsMessage,
  fetchImpl: typeof fetch = fetch,
): Promise<SmsResult> {
  const host = infobipHostOf(baseUrl);
  if (!host) return { ok: false, error: "infobip_base_url_invalid" };

  const body: Record<string, unknown> = {
    messages: [
      {
        ...(message.sender ? { sender: message.sender } : {}),
        destinations: [{ to: message.to }],
        content: { text: message.text },
      },
    ],
  };

  let response: Response;
  try {
    response = await fetchImpl(`https://${host}${MESSAGES_PATH}`, {
      method: "POST",
      headers: {
        // Infobip authenticates with the `App` scheme, not `Bearer`.
        Authorization: `App ${apiKey}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify(body),
    });
  } catch (error) {
    return {
      ok: false,
      error: error instanceof Error ? error.message : String(error),
    };
  }

  const text = await response.text();
  if (!response.ok) {
    return { ok: false, error: `infobip ${response.status}: ${describe(text)}` };
  }

  // A 200 from Infobip means the request was well formed, not that the
  // message reached the network: the per-destination status is inside the
  // body. An invalid destination therefore has to be read there, or the hook
  // would tell GoTrue a code was sent to a number that never got one.
  let parsed: any = null;
  try {
    parsed = text ? JSON.parse(text) : null;
  } catch {
    parsed = null;
  }
  const refusal = refusalOf(parsed);
  if (refusal) {
    return { ok: false, error: `infobip refused: ${refusal}`.slice(0, 220) };
  }
  const messageId = parsed?.messageId ?? parsed?.groupId;
  return {
    ok: true,
    messageId: messageId === undefined ? undefined : String(messageId),
  };
}

/// The reason a 200 answer is really a refusal, or null when it is not.
function refusalOf(body: any): string | null {
  const statuses = Array.isArray(body?.messageStatus)
    ? body.messageStatus
    : [];
  for (const entry of statuses) {
    const description = String(
      entry?.status?.description ?? entry?.status?.name ?? "",
    );
    if (/error|reject|invalid|undeliver|unreach|blocked|not\s*allowed/i.test(description)) {
      return describe(description) || "destination rejected";
    }
  }
  return null;
}

/// The shortest part of a provider answer that is safe to log or return.
function describe(text: string): string {
  const trimmed = (text ?? "").trim();
  if (!trimmed) return "";
  try {
    const parsed = JSON.parse(trimmed);
    const message =
      typeof parsed?.errorMessage === "string"
        ? parsed.errorMessage
        : typeof parsed?.detail === "string"
        ? parsed.detail
        : typeof parsed?.message === "string"
        ? parsed.message
        : "";
    const requestId =
      typeof parsed?.requestId === "string" ? parsed.requestId : "";
    const safe = [message, requestId && `requestId=${requestId}`]
      .filter(Boolean)
      .join(" ");
    return (safe || trimmed).slice(0, 160);
  } catch {
    return trimmed.slice(0, 160);
  }
}
