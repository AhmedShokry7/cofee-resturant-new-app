// Supabase Edge Function: send-sms
//
// The entry point of the function. The behaviour lives in `handler.ts` so the
// signature rules and the provider shape can be tested without opening a
// listening socket.
//
// This is an auth hook: Supabase calls it with a signed request, so it is
// deployed with --no-verify-jwt and proves the signature itself. Every request
// that is not signed by this project's hook secret is refused before the
// provider is contacted.
import { handleSmsRequest } from "./handler.ts";

Deno.serve((req) => handleSmsRequest(req));
