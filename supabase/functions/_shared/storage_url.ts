// supabase/functions/_shared/storage_url.ts
//
// The one rule that decides whether a picture named in a notification may
// travel to a device.
//
// Both delivery channels need the same answer, and the answer is a security
// check, so it lives in one file: the push shows the URL inside the Android
// banner and the mail shows it inside the message body, and in both cases the
// value was chosen by an admin and is read by a phone that has no session.

/// The buckets whose public objects may be shown in a notification.
const PUBLIC_IMAGE_BUCKETS = ["product-images"];

/// The longest URL a provider is handed.
const MAX_IMAGE_URL_LENGTH = 2048;

/// The host the storage objects of this project are read from.
export function storageHostOf(supabaseUrl: string | undefined): string | null {
  if (!supabaseUrl) return null;
  try {
    return new URL(supabaseUrl).host;
  } catch {
    return null;
  }
}

/// The public picture of a campaign, or null when it is not one.
///
/// A URL that carries credentials, points at another host, or comes from a
/// private bucket would leak whatever secret rides in it to whoever the
/// message is shown to, or hand out a link that dies before the device fetches
/// it: a signed URL expires in an hour and a private object answers 404.
export function publicImageUrlOf(
  raw: unknown,
  allowedHost: string | null,
): string | null {
  if (typeof raw !== "string") return null;
  const text = raw.trim();
  if (text.length === 0 || text.length > MAX_IMAGE_URL_LENGTH) return null;
  if (!allowedHost) return null;
  let url: URL;
  try {
    url = new URL(text);
  } catch {
    return null;
  }
  if (url.protocol !== "https:" || url.host !== allowedHost) return null;
  if (url.username !== "" || url.password !== "") return null;
  return PUBLIC_IMAGE_BUCKETS.some((bucket) =>
    url.pathname.startsWith(`/storage/v1/object/public/${bucket}/`)
  )
    ? url.toString()
    : null;
}
