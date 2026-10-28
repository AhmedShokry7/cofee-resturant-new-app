-- 198_record_live_admin_set_branch_image_audit.sql
--
-- Closes decision D3 of supabase/proposals/196_body_drift_owner_decisions.PROPOSED.sql,
-- with the opposite choice from the one the proposal recommended, because the
-- proposal read the live body wrong.
--
-- What D3 claimed: the live function "stores the full row snapshot of the branch
-- in the old-value column". What it actually does: `to_jsonb(b)` is a transient
-- local used only to test existence and to reach the previous value, and the
-- audit row receives
--
--     old  = jsonb_build_object('image_url', v_old->'image_url')
--     new  = jsonb_build_object('image_url', v_url)
--
-- That is one key, not a branch snapshot. So the live behaviour is a better
-- audit trail than 171's: `identity.audit` shows which URL was replaced, which
-- is what an admin reading the log wants, and nothing sensitive is added — the
-- same URL the branches panel already displays. The 171 payload records only
-- "had a picture / has a picture".
--
-- Therefore this file RECORDS the deployed definition instead of applying the
-- chain one, which is the rule this chain has followed for 190, 191 and 194:
-- recording is for behaviour that is real and correct, and applying-the-chain is
-- for behaviour that is real and wrong. D2 above was the second case; this is
-- the first.
--
-- Verified against pg_get_functiondef on webzzasosevzymftgszn on 2026-10-27, and
-- rehearsed inside a rolled-back transaction before being marked applied. The
-- written column (core.branches.image_url), the guards, the return shape
-- ('ok' / 'reason') and the ACL are unchanged from 171: only what lands in
-- identity.audit_log differs.

create or replace function public.admin_set_branch_image(
  p_branch_id uuid,
  p_image_url text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_url text := nullif(btrim(coalesce(p_image_url, '')), '');
  v_old jsonb;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('settings.write') then
    raise exception 'missing permission: settings.write' using errcode = '42501';
  end if;
  if p_branch_id is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if v_url is not null and v_url !~* '^https?://' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_url');
  end if;

  select to_jsonb(b) into v_old
    from core.branches b
   where b.id = p_branch_id;
  if v_old is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  update core.branches
     set image_url = v_url
   where id = p_branch_id;

  perform identity.audit(
    'core.branch.image',
    'branch',
    p_branch_id,
    jsonb_build_object('image_url', v_old->'image_url'),
    jsonb_build_object('image_url', v_url)
  );

  return jsonb_build_object('ok', true);
end;
$fn$;

comment on function public.admin_set_branch_image is
  'Record or clear the picture URL of a branch. The audit row keeps the previous '
  'and the new URL, not a branch snapshot.';

revoke all on function public.admin_set_branch_image(uuid, text) from public, anon;
grant execute on function public.admin_set_branch_image(uuid, text) to authenticated;

notify pgrst, 'reload schema';
