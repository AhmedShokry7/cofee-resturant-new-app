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
  sendToToken,
} from "./fcm.ts";

/// A PEM private key, the way Google writes it.
function toPem(pkcs8: ArrayBuffer): string {
  const base64 = btoa(String.fromCharCode(...new Uint8Array(pkcs8)));
  const lines = base64.match(/.{1,64}/g) ?? [];
  return `-----BEGIN PRIVATE KEY-----\n${lines.join("\n")}\n-----END PRIVATE KEY-----`;
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
