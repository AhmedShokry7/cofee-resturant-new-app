// Supabase Edge Function: ai-assistant
//
// The entry point of the function. The behaviour lives in `handler.ts` so it
// can be tested without opening a listening socket.
import { handleRequest } from "./handler.ts";

Deno.serve((req) => handleRequest(req));
