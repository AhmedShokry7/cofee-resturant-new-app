import { handleRequest } from './index.ts';

Deno.test('webhook rejects forged tokens and production events in sandbox; accepts setup without live flag', async () => {
  const previousToken = Deno.env.get('MOYASAR_WEBHOOK_SECRET_TOKEN');
  const previousMode = Deno.env.get('MOYASAR_MODE');
  Deno.env.set('MOYASAR_WEBHOOK_SECRET_TOKEN', 'unit-test-token');
  Deno.env.set('MOYASAR_MODE', 'sandbox');
  try {
    for (const [body, status] of [
      [{type:'payment_paid', secret_token:'forged', live:false}, 401],
      [{type:'payment_paid', secret_token:'unit-test-token', live:true}, 403],
      [{type:'webhook_verification', secret_token:'unit-test-token'}, 200],
    ] as const) {
      const result = await handleRequest(new Request('https://local.invalid', {
        method:'POST', body:JSON.stringify(body),
      }));
      if (result.status !== status) throw new Error(`Unexpected status ${result.status}`);
      await result.body?.cancel();
    }
  } finally {
    if (previousToken === undefined) Deno.env.delete('MOYASAR_WEBHOOK_SECRET_TOKEN');
    else Deno.env.set('MOYASAR_WEBHOOK_SECRET_TOKEN', previousToken);
    if (previousMode === undefined) Deno.env.delete('MOYASAR_MODE');
    else Deno.env.set('MOYASAR_MODE', previousMode);
  }
});
