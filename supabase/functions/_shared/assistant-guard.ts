// supabase/functions/_shared/assistant-guard.ts
//
// Guard helpers for the `ai-assistant` Edge Function.
//
// Everything here is pure: no Deno globals, no network, no database. The
// decisions that decide *who* a request is and *whether* a request may reach
// a paid provider therefore can be tested without touching anything.
//
// ---------------------------------------------------------------------------
// On the client IP (F1)
// ---------------------------------------------------------------------------
//
// The address of a caller is read from `X-Forwarded-For`, and only from the
// **rightmost** entry of the chain.
//
// Why the rightmost one:
//   * `X-Forwarded-For` is a chain. Every proxy appends the address it
//     received the request from, so the entries to the LEFT are whatever the
//     caller sent, and the entry to the RIGHT is the one the proxy nearest
//     the function added. MDN, http.dev and adam-p.ca all say the same: the
//     leftmost value is attacker controlled and must never be used for
//     rate limiting; only the value added by a trusted proxy is usable.
//   * The rightmost entry is safe under either platform behaviour: when the
//     gateway OVERWRITES the header (as the Supabase nginx template does
//     with `proxy_set_header X-Forwarded-For $remote_addr`) the chain holds
//     one entry and it is the caller's address; when the gateway APPENDS, the
//     rightmost entry is still the one it added.
//   * A forged prefix cannot reach the rightmost position, so a caller
//     cannot choose the bucket it is counted in by sending a header.
//
// Assumptions that are NOT verified by this project, and that the code
// therefore refuses to lean on:
//   * that the platform overwrites or appends to `X-Forwarded-For` at all.
//     If a deployment passed the header through untouched, the rightmost
//     entry would be the caller's. Supabase does not document the behaviour
//     for Edge Functions, so the risk is reported rather than hidden.
//   * that no proxy sits between the platform and the function and appends
//     its own entry. Such an entry is still not caller controlled, it only
//     makes the bucket coarser.
//
// What is deliberately NOT used:
//   * the leftmost entry (caller controlled),
//   * `cf-connecting-ip` and `x-real-ip` (caller controlled unless the
//     platform overwrites them, which is not documented for this platform),
//   * any "unknown" placeholder as a bucket key: every unidentified caller
//     would collapse into one shared bucket.
//
// A caller whose address cannot be established is reported as
// `unidentified`, and the caller is refused rather than counted.

export type CallerIdentity =
  | { kind: "user"; key: string }
  | { kind: "guest"; key: string }
  | { kind: "unidentified"; key: null };

/** IPv4 dotted quad, 4 octets, each 0-255. */
const IPV4_PATTERN = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;

/** Lowercase hex groups separated by colons, at least one group. */
const IPV6_PATTERN = /^[0-9a-f:]+$/;

function isIpv4(value: string): boolean {
  const match = IPV4_PATTERN.exec(value);
  if (!match) return false;
  for (let i = 1; i <= 4; i++) {
    const octet = Number(match[i]);
    if (!Number.isInteger(octet) || octet < 0 || octet > 255) return false;
    // A leading zero is ambiguous (octal in some parsers).
    if (match[i].length > 1 && match[i].startsWith("0")) return false;
  }
  return true;
}

function isIpv6(value: string): boolean {
  if (!value.includes(":")) return false;
  if (!IPV6_PATTERN.test(value)) return false;
  if ((value.match(/::/g) ?? []).length > 1) return false;
  // At most one "::" and at least one group.
  const groups = value.split(":").filter((part) => part.length > 0);
  if (groups.length === 0) return false;
  for (const group of groups) {
    if (!/^[0-9a-f]{1,4}$/.test(group)) {
      // The last group may be an embedded IPv4 address.
      if (group.includes(".") && isIpv4(group)) continue;
      return false;
    }
  }
  return true;
}

function isPrivateIpv4(value: string): boolean {
  const octets = value.split(".").map(Number);
  const [a, b] = octets;
  if (a === 0) return true; // 0.0.0.0/8 "this network"
  if (a === 10) return true; // 10/8 private
  if (a === 127) return true; // 127/8 loopback
  if (a === 100 && b >= 64 && b <= 127) return true; // 100.64/10 carrier NAT
  if (a === 169 && b === 254) return true; // 169.254/16 link local
  if (a === 172 && b >= 16 && b <= 31) return true; // 172.16/12 private
  if (a === 192 && b === 168) return true; // 192.168/16 private
  if (a >= 224) return true; // multicast and reserved
  return false;
}

function isPrivateIpv6(value: string): boolean {
  if (value === "::" || value === "::1") return true; // unspecified, loopback
  if (value.startsWith("fc") || value.startsWith("fd")) return true; // fc00::/7 unique local
  if (value.startsWith("fe8") || value.startsWith("fe9") ||
      value.startsWith("fea") || value.startsWith("feb")) return true; // fe80::/10 link local
  if (value.startsWith("ff")) return true; // ff00::/8 multicast
  // IPv4 mapped (::ffff:a.b.c.d) inherits the IPv4 rules.
  const mapped = /^::ffff:(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/.exec(value);
  if (mapped && isIpv4(mapped[1])) return isPrivateIpv4(mapped[1]);
  return false;
}

/**
 * Normalizes an address to its canonical text form, or returns null when the
 * value is not an address this function is willing to use.
 *
 * Rejected: anything that is not an address, and every address in a range
 * that cannot belong to a public caller (loopback, private, link local,
 * carrier NAT, multicast, unspecified).
 */
export function normalizeIp(raw: string | null | undefined): string | null {
  if (typeof raw !== "string") return null;
  let candidate = raw.trim().toLowerCase();
  if (!candidate) return null;

  // "[2001:db8::1]:8080" -> "2001:db8::1"
  if (candidate.startsWith("[")) {
    const end = candidate.indexOf("]");
    if (end < 0) return null;
    candidate = candidate.slice(1, end);
  } else if (candidate.includes(".") && candidate.split(":").length === 2) {
    // "1.2.3.4:5678" -> "1.2.3.4"
    candidate = candidate.slice(0, candidate.lastIndexOf(":"));
  }

  if (isIpv4(candidate)) {
    return isPrivateIpv4(candidate) ? null : candidate;
  }
  if (isIpv6(candidate)) {
    return isPrivateIpv6(candidate) ? null : candidate;
  }
  return null;
}

/**
 * The caller's address, taken from the rightmost `X-Forwarded-For` entry.
 *
 * Only the last entry is considered. If it is not a usable address the
 * caller is reported as unidentified rather than falling back to an entry
 * further left, because those entries are the ones the caller sent.
 */
export function clientIpFromRequest(req: Request): string | null {
  const header = req.headers.get("x-forwarded-for");
  if (!header) return null;
  // The Fetch specification joins repeated headers with ", ", so a forged
  // prefix and the platform entry arrive as one chain.
  const entries = header.split(",").map((entry) => entry.trim()).filter(Boolean);
  if (entries.length === 0) return null;
  return normalizeIp(entries[entries.length - 1]);
}

export async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/**
 * The bucket a request is counted in.
 *
 * A signed-in customer is counted under their verified user id, which needs
 * no address at all. A guest is counted under a hash of their address, so the
 * address itself is never stored or logged.
 */
export async function buildCallerIdentity(
  userId: string | null,
  req: Request,
): Promise<CallerIdentity> {
  if (userId) return { kind: "user", key: `user:${userId}` };
  const ip = clientIpFromRequest(req);
  if (!ip) return { kind: "unidentified", key: null };
  return { kind: "guest", key: `guest:${await sha256Hex(ip)}` };
}

// ---------------------------------------------------------------------------
// On the limiter decision (F2, F3)
// ---------------------------------------------------------------------------

export type QuotaFailureReason =
  | "missing_env"
  | "rpc_error"
  | "rpc_timeout"
  | "malformed_response"
  | "permission_denied"
  | "unidentified_caller";

export type QuotaResult =
  | { kind: "allow"; remaining: number; resetAt: string | null }
  | { kind: "deny"; remaining: number; resetAt: string | null }
  | { kind: "unavailable"; reason: QuotaFailureReason };

/** The limits the assistant enforces. */
export const RATE_LIMIT_USER = 60;
export const RATE_LIMIT_GUEST = 15;
export const RATE_LIMIT_WINDOW_SECONDS = 3600;

export function limitFor(identity: CallerIdentity): number {
  return identity.kind === "user" ? RATE_LIMIT_USER : RATE_LIMIT_GUEST;
}

/**
 * Turns the answer of the counter RPC into a decision.
 *
 * Anything that is not an explicit "not allowed" is NOT treated as an
 * allowance: a malformed answer is a failure, not a permission.
 */
export function interpretQuotaRow(
  row: unknown,
  limit: number,
): QuotaResult {
  if (!row || typeof row !== "object") {
    return { kind: "unavailable", reason: "malformed_response" };
  }
  const record = row as Record<string, unknown>;
  if (typeof record.allowed !== "boolean") {
    return { kind: "unavailable", reason: "malformed_response" };
  }
  const remaining = Number(record.remaining);
  const resetAt = typeof record.reset_at === "string" ? record.reset_at : null;
  if (record.allowed === false) {
    return { kind: "deny", remaining: 0, resetAt };
  }
  if (!Number.isFinite(remaining) || remaining < 0) {
    return { kind: "unavailable", reason: "malformed_response" };
  }
  return { kind: "allow", remaining, resetAt };
}

/** Seconds the caller has to wait, when the counter says so. */
export function retryAfterSeconds(resetAt: string | null, now: Date): number | null {
  if (!resetAt) return null;
  const reset = Date.parse(resetAt);
  if (Number.isNaN(reset)) return null;
  const seconds = Math.ceil((reset - now.getTime()) / 1000);
  return seconds > 0 ? seconds : 0;
}
