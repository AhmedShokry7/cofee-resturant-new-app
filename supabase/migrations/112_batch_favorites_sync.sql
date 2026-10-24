-- Mirror device favourites in one database request during account sync.
-- Security invoker preserves the caller's grants and owner-only RLS policy.
create or replace function public.sync_customer_favorites(p_product_ids uuid[])
returns integer
language plpgsql
security invoker
set search_path to ''
as $fn$
declare
  inserted_count integer;
begin
  if auth.uid() is null then
    raise exception 'Sign-in is required to sync favorites'
      using errcode = '42501';
  end if;

  insert into engagement.customer_favorites (user_id, product_id)
  select auth.uid(), requested.product_id
    from unnest(coalesce(p_product_ids, array[]::uuid[])) as requested(product_id)
   where requested.product_id is not null
  on conflict (user_id, product_id) do nothing;

  get diagnostics inserted_count = row_count;
  return inserted_count;
end;
$fn$;

comment on function public.sync_customer_favorites(uuid[]) is
  'Batch-mirrors the authenticated customer favorites; owner RLS remains enforced.';

revoke all on function public.sync_customer_favorites(uuid[]) from public, anon;
grant execute on function public.sync_customer_favorites(uuid[])
  to authenticated;

notify pgrst, 'reload schema';
