// supabase/functions/_shared/assistant-guard.test.ts
//
// F1: the caller's address must come from a value the caller cannot choose.
//
// The tests below prove the property that matters: sending a header can
// never move a request into a different rate limit bucket.
import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildCallerIdentity,
  clientIpFromRequest,
  interpretQuotaRow,
  normalizeIp,
  retryAfterSeconds,
} from "./assistant-guard.ts";

function requestWith(headers: Record<string, string>): Request {
  return new Request("https://example.test/functions/v1/ai-assistant", {
    method: "POST",
    headers,
  });
}

Deno.test("a forged x-forwarded-for cannot choose the bucket", async () => {
  // The platform appends its own entry to whatever the caller sent. The
  // caller controls the left of the chain, never the right.
  const forged = requestWith({
    "x-forwarded-for": "10.0.0.7, 203.0.113.9",
  });
  const trusted = requestWith({
    "x-forwarded-for": "203.0.113.9",
  });

  assertEquals(
    clientIpFromRequest(forged),
    clientIpFromRequest(trusted),
    "a forged prefix must not change the identity",
  );
  assertEquals(clientIpFromRequest(forged), "203.0.113.9");
});

Deno.test("rotating the forged value keeps one identity", async () => {
  const keys = new Set<string>();
  for (const spoofed of ["10.0.0.1", "10.0.0.2", "10.0.0.3", "10.0.0.4"]) {
    const identity = await buildCallerIdentity(
      null,
      requestWith({ "x-forwarded-for": `${spoofed}, 203.0.113.9` }),
    );
    assertEquals(identity.kind, "guest");
    keys.add(identity.key as string);
  }
  assertEquals(keys.size, 1, "every request landed in the same bucket");
});

Deno.test("a valid trusted source is used", async () => {
  assertEquals(
    clientIpFromRequest(requestWith({ "x-forwarded-for": "198.51.100.7" })),
    "198.51.100.7",
  );
  assertEquals(
    clientIpFromRequest(requestWith({ "x-forwarded-for": "2001:db8::1" })),
    "2001:db8::1",
  );
});

Deno.test("a missing header leaves the caller unidentified", async () => {
  assertEquals(clientIpFromRequest(requestWith({})), null);
  const identity = await buildCallerIdentity(null, requestWith({}));
  assertEquals(identity.kind, "unidentified");
  assertEquals(identity.key, null);
});

Deno.test("malformed metadata is refused rather than guessed", async () => {
  for (const bad of [
    "not-an-ip",
    "999.999.999.999",
    "203.0.113.9.7",
    "203.0.113.9:80:80",
    "",
    "   ",
    "localhost",
  ]) {
    assertEquals(
      clientIpFromRequest(requestWith({ "x-forwarded-for": bad })),
      null,
      `accepted a malformed address: ${bad}`,
    );
  }
});

Deno.test("the last entry is the only one that counts", async () => {
  // A forged chain whose last entry is malformed must not fall back to the
  // forged entries to the left of it.
  const req = requestWith({ "x-forwarded-for": "10.0.0.7, garbage" });
  assertEquals(clientIpFromRequest(req), null);
});

Deno.test("private and reserved addresses are not client identities", async () => {
  for (const privateIp of [
    "127.0.0.1",
    "10.1.2.3",
    "172.16.5.4",
    "192.168.1.1",
    "169.254.1.1",
    "100.64.0.1",
    "0.0.0.0",
    "224.0.0.1",
    "::1",
    "fc00::1",
    "fe80::1",
    "::",
  ]) {
    assertEquals(
      normalizeIp(privateIp),
      null,
      `accepted a non-public address: ${privateIp}`,
    );
  }
});

Deno.test("an address with a port or brackets is normalized", () => {
  assertEquals(normalizeIp("203.0.113.9:44321"), "203.0.113.9");
  assertEquals(normalizeIp("[2001:db8::1]:8080"), "2001:db8::1");
  assertEquals(normalizeIp("  203.0.113.9  "), "203.0.113.9");
});

Deno.test("a forged header cannot take a signed-in customer out of their bucket", async () => {
  const userId = "11111111-2222-3333-4444-555555555555";
  const withForged = await buildCallerIdentity(
    userId,
    requestWith({ "x-forwarded-for": "10.0.0.7, 203.0.113.9" }),
  );
  assertEquals(withForged.kind, "user");
  assertEquals(withForged.key, `user:${userId}`);
});

Deno.test("a guest identity never contains the raw address", async () => {
  const identity = await buildCallerIdentity(
    null,
    requestWith({ "x-forwarded-for": "203.0.113.9" }),
  );
  assertEquals(identity.kind, "guest");
  assertEquals(String(identity.key).includes("203.0.113.9"), false);
  assertEquals(String(identity.key).startsWith("guest:"), true);
});

Deno.test("a guest and a signed-in customer get different limits", async () => {
  const guest = await buildCallerIdentity(
    null,
    requestWith({ "x-forwarded-for": "203.0.113.9" }),
  );
  const user = await buildCallerIdentity(
    "11111111-2222-3333-4444-555555555555",
    requestWith({ "x-forwarded-for": "203.0.113.9" }),
  );
  assertEquals(guest.kind, "guest");
  assertEquals(user.kind, "user");
  assertEquals(guest.key === user.key, false);
});

Deno.test("a malformed counter answer is a failure, not an allowance", () => {
  assertEquals(interpretQuotaRow(null, 15).kind, "unavailable");
  assertEquals(interpretQuotaRow({}, 15).kind, "unavailable");
  assertEquals(interpretQuotaRow({ allowed: "yes" }, 15).kind, "unavailable");
  assertEquals(
    interpretQuotaRow({ allowed: true, remaining: "many" }, 15).kind,
    "unavailable",
  );
  assertEquals(interpretQuotaRow({ allowed: true, remaining: 3 }, 15).kind, "allow");
  assertEquals(
    interpretQuotaRow({ allowed: false, remaining: 0 }, 15).kind,
    "deny",
  );
});

Deno.test("the retry hint comes from the window the counter reported", () => {
  const now = new Date("2026-10-20T12:00:00.000Z");
  assertEquals(
    retryAfterSeconds("2026-10-20T12:30:00.000Z", now),
    1800,
  );
  assertEquals(retryAfterSeconds("2026-10-20T11:00:00.000Z", now), 0);
  assertEquals(retryAfterSeconds(null, now), null);
  assertEquals(retryAfterSeconds("not-a-date", now), null);
});
