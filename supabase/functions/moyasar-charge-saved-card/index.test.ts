import { savedCardAttemptId } from './index.ts';

Deno.test('concurrent saved-card submissions share one UUID, terminal failure permits a new attempt', async () => {
  const [first, duplicate, retry, other] = await Promise.all([
    savedCardAttemptId('user:order'), savedCardAttemptId('user:order'),
    savedCardAttemptId('user:order', 'failed-payment'), savedCardAttemptId('user:other-order'),
  ]);
  if (first !== duplicate || first === retry || first === other) throw new Error('Unsafe attempt identity');
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(first)) throw new Error('Invalid UUID');
});
