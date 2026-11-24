import { tapBaseUrl, tapSecretKey } from "./tap.ts";

function assertEquals(actual: unknown, expected: unknown): void {
  if (actual !== expected) {
    throw new Error(`Expected ${expected}, got ${actual}`);
  }
}

function assertThrows(action: () => unknown, message: string): void {
  try {
    action();
  } catch (error) {
    if (error instanceof Error && error.message.includes(message)) return;
    throw error;
  }
  throw new Error(`Expected error containing ${message}`);
}

Deno.test("Tap sandbox and production modes require matching key prefixes", () => {
  const oldEnv = {
    mode: Deno.env.get("TAP_ENV"),
    key: Deno.env.get("TAP_SECRET_KEY"),
  };
  try {
    Deno.env.set("TAP_ENV", "sandbox");
    Deno.env.set("TAP_SECRET_KEY", "sk_test_local_fixture");
    assertEquals(tapSecretKey(), "sk_test_local_fixture");
    Deno.env.set("TAP_SECRET_KEY", "sk_live_local_fixture");
    assertThrows(() => tapSecretKey(), "requires a Tap test secret key");
    Deno.env.set("TAP_ENV", "production");
    Deno.env.set("TAP_SECRET_KEY", "sk_test_local_fixture");
    assertThrows(() => tapSecretKey(), "requires a Tap live secret key");
    Deno.env.set("TAP_SECRET_KEY", "sk_live_local_fixture");
    assertEquals(tapSecretKey(), "sk_live_local_fixture");
    assertEquals(tapBaseUrl(), "https://api.tap.company/v2");
  } finally {
    if (oldEnv.mode === undefined) Deno.env.delete("TAP_ENV");
    else Deno.env.set("TAP_ENV", oldEnv.mode);
    if (oldEnv.key === undefined) Deno.env.delete("TAP_SECRET_KEY");
    else Deno.env.set("TAP_SECRET_KEY", oldEnv.key);
  }
});
