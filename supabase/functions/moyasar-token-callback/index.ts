// Moyasar returns the cardholder here after its 3D Secure verification.
// No card or token data is accepted or written by this public endpoint.
Deno.serve(() => new Response(
  "ارجع إلى تطبيق New Coffee لإكمال حفظ البطاقة. سيؤكد التطبيق حالة البطاقة مع مويسر أولًا.",
  { headers: { "Content-Type": "text/plain; charset=utf-8" } },
));
