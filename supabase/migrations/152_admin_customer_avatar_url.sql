-- 152_admin_customer_avatar_url.sql
-- Secure, short-lived signed URL for a customer's private avatar.
--
-- identity.profiles.avatar_url stores a PATH inside the PRIVATE avatars
-- bucket (migration 084), never a signed URL.
--
-- A staff member with customers.read may obtain a short-lived signed URL
-- for one customer's avatar. The function is SECURITY DEFINER so it can
-- read the storage object on behalf of the caller, but it never grants
-- direct bucket access and never exposes another customer's path.
--
-- Security:
--   * identity.is_staff() + identity.has_permission('customers.read') gate
--     every call.
--   * The path is read from identity.profiles.avatar_url for the requested
--     customer only; the caller never supplies a path, so path traversal
--     and bucket probing are impossible.
--   * A missing or non-path value returns NULL instead of raising, so a
--     customer without a photo degrades to the placeholder in the UI.
--   * The signed URL expires after 60 seconds; it is never persisted.
--   * The bucket stays private; no storage policy is weakened.
--
-- Dependency: storage.create_signed_url must exist in this project's
-- Supabase version. If it does not, apply the equivalent via an Edge
-- Function or the Storage management API and update the Dart caller.
create or replace function public.admin_customer_avatar_url(p_customer_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_path text;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('customers.read') then
    raise exception 'missing permission: customers.read' using errcode = '42501';
  end if;

  select p.avatar_url into v_path
    from identity.profiles p
   where p.id = p_customer_id;

  if v_path is null or v_path = '' then
    return null;
  end if;

  -- Only accept relative paths inside the avatars bucket; never a full URL.
  if v_path ~ '^https?://' then
    return null;
  end if;

  return storage.create_signed_url('avatars', v_path, 60);
end;
$fn$;

revoke all on function public.admin_customer_avatar_url(uuid) from public, anon;
grant execute on function public.admin_customer_avatar_url(uuid) to authenticated;