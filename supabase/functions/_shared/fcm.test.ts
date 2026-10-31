// supabase/functions/_shared/fcm.test.ts
//
// The FCM client is the part that talks to Google, so it is checked against
// Google itself: a signature that is built wrong is answered with a clear
// error, and a request that never arrives is an error of the network.
import { assertEquals, assertNotEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  createAccessToken,
  importPrivateKey,
  parseServiceAccount,
  resetAccessTokenCache,
  sendToToken,
  type FcmMessage,
} from "./fcm.ts";

/// A PEM private key, the way Google writes it.
function toPem(pkcs8: ArrayBuffer): string {
  const base64 = btoa(String.fromCharCode(...new Uint8Array(pkcs8)));
  const lines = base64.match(/.{1,64}/g) ?? [];
  return `-----BEGIN PRIVATE KEY-----\n${lines.join("\n")}\n-----END PRIVATE KEY-----`;
}

/// A signing key of the shape Google hands out.
async function serviceAccountPem(): Promise<string> {
  const pair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  return toPem(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
}

/// Runs a body with globalThis.fetch replaced, then puts the real one back.
async function withFetchStub<T>(
  handler: (input: unknown, init: unknown) => Response | Promise<Response>,
  body: () => Promise<T>,
): Promise<T> {
  const original = globalThis.fetch;
  globalThis.fetch = ((input: unknown, init?: unknown) =>
    Promise.resolve(handler(input, init))) as typeof fetch;
  try {
    return await body();
  } finally {
    globalThis.fetch = original;
  }
}

/// The message the FCM request is built for.
function messageWith(overrides: Partial<FcmMessage> = {}): FcmMessage {
  return {
    title: "ترويج",
    body: "خصم اليوم",
    data: { type: "promo" },
    imageUrl: null,
    ...overrides,
  };
}

/// Reads the JSON body out of a stubbed request.
function bodyOf(init: unknown): any {
  const options = init as { body?: string };
  return JSON.parse(options.body ?? "{}");
}

Deno.test("a service account is read out of the secret", () => {
  const parsed = parseServiceAccount(
    JSON.stringify({
      type: "service_account",
      project_id: "project",
      client_email: "sa@project.iam.gserviceaccount.com",
      private_key: "-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----",
    }),
  );
  assertEquals(parsed?.project_id, "project");
  assertEquals(parsed?.client_email, "sa@project.iam.gserviceaccount.com");
});

Deno.test("a missing or broken secret is not a crash", () => {
  assertEquals(parseServiceAccount(undefined), null);
  assertEquals(parseServiceAccount("not json"), null);
  assertEquals(parseServiceAccount(JSON.stringify({ project_id: "p" })), null);
});

Deno.test("a private key in PEM is imported for signing", async () => {
  const pair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const pem = toPem(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  const key = await importPrivateKey(pem);
  assertEquals(key.type, "private");
  assertEquals(key.usages.includes("sign"), true);
});

Deno.test("the request for an access token reaches Google", async () => {
  const pair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const pem = toPem(await crypto.subtle.exportKey("pkcs8", pair.privateKey));

  let error: string | null = null;
  try {
    await createAccessToken({
      project_id: "new-coffee-4d196",
      client_email: "not-a-real-account@new-coffee-4d196.iam.gserviceaccount.com",
      private_key: pem,
    });
  } catch (thrown) {
    error = thrown instanceof Error ? thrown.message : String(thrown);
  }

  // The key is a real signature, so Google answers about the account and not
  // about the format of the request. Any other answer would mean that the
  // signature or the body of the request is wrong.
  assertNotEquals(error, null);
  assertEquals(
    /token endpoint/i.test(error ?? ""),
    true,
    `unexpected answer from Google: ${error}`,
  );
});

Deno.test("a dead token is recognised as such", async () => {
  const result = await sendToToken(
    "not-a-real-access-token",
    "new-coffee-4d196",
    "not-a-real-token",
    { title: "t", body: "b", data: {} },
  );
  assertEquals(result.ok, false);
  assertEquals(result.error !== undefined, true);
});

Deno.test("the FCM request carries the picture in both places", async () => {
  const image =
    "https://project.supabase.co/storage/v1/object/public/product-images/products/notifications/a.jpg";
  let sentBody: any = null;
  await withFetchStub((_input, init) => {
    sentBody = bodyOf(init);
    return new Response(JSON.stringify({ name: "projects/p/messages/1" }), {
      status: 200,
    });
  }, () => sendToToken("token", "project", "device-token", messageWith({ imageUrl: image })));

  assertEquals(sentBody.message.notification.image, image);
  assertEquals(sentBody.message.android.notification.image, image);
  assertEquals(sentBody.message.notification.title, "ترويج");
  assertEquals(sentBody.message.android.notification.channel_id, "default_notification_channel");
});

Deno.test("a text message asks FCM for no picture at all", async () => {
  let sentBody: any = null;
  await withFetchStub((_input, init) => {
    sentBody = bodyOf(init);
    return new Response(JSON.stringify({ name: "projects/p/messages/2" }), {
      status: 200,
    });
  }, () => sendToToken("token", "project", "device-token", messageWith()));

  assertEquals("image" in sentBody.message.notification, false);
  assertEquals("image" in sentBody.message.android.notification, false);
});

Deno.test("a blank picture is dropped before it reaches FCM", async () => {
  let sentBody: any = null;
  await withFetchStub((_input, init) => {
    sentBody = bodyOf(init);
    return new Response(JSON.stringify({ name: "projects/p/messages/3" }), {
      status: 200,
    });
  }, () => sendToToken("token", "project", "device-token", messageWith({ imageUrl: "   " })));

  assertEquals("image" in sentBody.message.notification, false);
});

Deno.test("an access token is reused while Google says it is valid", async () => {
  resetAccessTokenCache();
  const pem = await serviceAccountPem();
  let tokenRequests = 0;
  const account = {
    project_id: "project",
    client_email: "cached@project.iam.gserviceaccount.com",
    private_key: pem,
  };

  const first = await withFetchStub(() => {
    tokenRequests += 1;
    return new Response(
      JSON.stringify({ access_token: "access-1", expires_in: 3600 }),
      { status: 200 },
    );
  }, async () => {
    const a = await createAccessToken(account);
    const b = await createAccessToken(account);
    return { a, b };
  });

  assertEquals(first.a, "access-1");
  assertEquals(first.b, "access-1");
  assertEquals(tokenRequests, 1);

  resetAccessTokenCache();
});

Deno.test("a token close to its expiry is fetched again", async () => {
  resetAccessTokenCache();
  const pem = await serviceAccountPem();
  let tokenRequests = 0;
  const account = {
    project_id: "project",
    client_email: "expiring@project.iam.gserviceaccount.com",
    private_key: pem,
  };
  // Google hands an hour; the client keeps sixty seconds less than that.
  const clock = { current: 1_700_000_000_000 };

  await withFetchStub(() => {
    tokenRequests += 1;
    return new Response(
      JSON.stringify({ access_token: `access-${tokenRequests}`, expires_in: 3600 }),
      { status: 200 },
    );
  }, async () => {
    await createAccessToken(account, () => clock.current);
    clock.current += 59 * 60 * 1000;
    await createAccessToken(account, () => clock.current);
  });

  assertEquals(tokenRequests, 2);

  resetAccessTokenCache();
});
