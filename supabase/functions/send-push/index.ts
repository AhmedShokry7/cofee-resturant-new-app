// Supabase Edge Function: send-push
//
// The entry point of the function. The behaviour lives in `handler.ts` so it
// can be tested without opening a listening socket.
//
// The function is called by the database trigger, not by the app, so it is
// deployed with --no-verify-jwt and checks the shared secret itself.
import { handleRequest } from "./handler.ts";

Deno.serve((req) => handleRequest(req));
