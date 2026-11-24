import { handleRequest } from "./index.ts";

function assertEquals(actual: unknown, expected: unknown): void {
  if (actual !== expected) {
    throw new Error(`expected ${String(expected)}, got ${String(actual)}`);
  }
}

const RUN = "b105bd82-18df-4e6a-9b10-306d5ed5e1bc";
const KEY = "SUPABASE_PUBLISHABLE_KEY";
const URL = "SUPABASE_URL";

Deno.test("checkout authentication and project pinning", async () => {
  Deno.env.set(URL, "https://webzzasosevzymftgszn.supabase.co");
  Deno.env.set(KEY, "test-public-key");
  let response = await handleRequest(
    new Request("https://function.test", {
      method: "POST",
      body: JSON.stringify({
        run_id: RUN,
        idempotency_key: "9a21d94b-d7dd-45b2-a48f-5cac588b1816",
      }),
    }),
    () => {
      throw new Error("unexpected fetch");
    },
  );
  assertEquals(response.status, 401);

  const calls: Request[] = [];
  const fetcher: typeof fetch = async (input, init) => {
    const request = new Request(input, init);
    calls.push(request);
    if (request.url.endsWith("/auth/v1/user")) {
      return Response.json({ id: "55ed60a0-792a-4b1a-9ab0-eaa215d74951" });
    }
    return Response.json({
      order_id: "d3211014-c572-4d69-93c4-2cb2bb4bf4f8",
      run_id: RUN,
      test_only: true,
    });
  };
  response = await handleRequest(
    new Request("https://function.test", {
      method: "POST",
      headers: { authorization: "Bearer unit-test-placeholder" },
      body: JSON.stringify({
        run_id: RUN,
        idempotency_key: "9a21d94b-d7dd-45b2-a48f-5cac588b1816",
      }),
    }),
    fetcher,
  );
  assertEquals(response.status, 200);
  assertEquals(calls.length, 2);
  assertEquals(
    calls[0].headers.get("authorization"),
    "Bearer unit-test-placeholder",
  );
  assertEquals(
    calls[1].headers.get("authorization"),
    "Bearer unit-test-placeholder",
  );
  assertEquals(calls[1].headers.get("apikey"), "test-public-key");
  Deno.env.set(URL, "https://different-project.supabase.co");
  response = await handleRequest(
    new Request("https://function.test", {
      method: "POST",
      headers: { authorization: "Bearer unit-test-placeholder" },
      body: JSON.stringify({
        run_id: RUN,
        idempotency_key: "9a21d94b-d7dd-45b2-a48f-5cac588b1816",
      }),
    }),
    () => {
      throw new Error("unexpected fetch");
    },
  );
  assertEquals(response.status, 403);
});
