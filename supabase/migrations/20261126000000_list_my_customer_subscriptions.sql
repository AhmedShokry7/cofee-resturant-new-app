create or replace function public.list_my_subscriptions()
returns table (
  id uuid, plan_id uuid, plan_name_ar text, plan_name_en text, status text,
  starts_at timestamptz, ends_at timestamptz, cups_entitled integer,
  cups_used integer, cups_carried_over integer, bonus_balance numeric,
  bonus_expires_at timestamptz, auto_renew boolean, created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $fn$
  select s.id, s.plan_id, p.name_ar, p.name_en, s.status, s.starts_at, s.ends_at,
         s.cups_entitled, s.cups_used, s.cups_carried_over, s.bonus_balance,
         s.bonus_expires_at, s.auto_renew, s.created_at
    from subscriptions.subscriptions s
    join subscriptions.plans p on p.id = s.plan_id
   where s.user_id = auth.uid()
   order by s.created_at desc;
$fn$;
revoke all on function public.list_my_subscriptions() from public, anon;
grant execute on function public.list_my_subscriptions() to authenticated;
