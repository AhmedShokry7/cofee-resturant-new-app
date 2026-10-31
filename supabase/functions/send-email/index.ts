// Supabase Edge Function: send-email
//
// The entry point of the function. The behaviour lives in `handler.ts` so it
// can be tested without opening a listening socket.
//
// The delivery is called by the database trigger, so it is deployed with
// --no-verify-jwt and checks the shared secret itself. The unsubscribe route
// is different: it is a link a customer clicks inside a mail client, with no
// session and no secret header, so it proves itself with a signed token.
import {
  handleEmailRequest,
  handleUnsubscribe,
  createSupabaseStore,
  unsubscribeTokenFor,
} from "./handler.ts";

Deno.serve((req) => {
  const path = new URL(req.url).pathname.replace(/\/+$/, "");
  if (!path.endsWith("/unsubscribe")) {
    return handleEmailRequest(req);
  }

  // The click needs the database too: the token is checked against the same
  // secret and the switch is written against the same row.
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  return handleUnsubscribe(req, {
    env: (name) => Deno.env.get(name),
    store: createSupabaseStore(
      supabaseUrl,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    ),
    unsubscribeToken: unsubscribeTokenFor,
  });
});
