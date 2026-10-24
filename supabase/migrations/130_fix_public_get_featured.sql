-- 130_fix_public_get_featured.sql
-- Keeps the public bridge in sync with catalog.get_featured after 129.
drop function if exists public.get_featured(uuid, integer);

create or replace function public.get_featured(
  p_branch_id uuid,
  p_limit integer default 10
)
returns table (
  product_id uuid,
  name_ar text,
  name_en text,
  image_url text,
  effective_price numeric,
  source text
)
language sql
stable
security invoker
set search_path = ''
as $function$
  select * from catalog.get_featured(p_branch_id, p_limit);
$function$;

revoke all on function public.get_featured(uuid, integer) from public;
revoke execute on function public.get_featured(uuid, integer) from anon;
grant execute on function public.get_featured(uuid, integer) to anon, authenticated;

notify pgrst, 'reload schema';
