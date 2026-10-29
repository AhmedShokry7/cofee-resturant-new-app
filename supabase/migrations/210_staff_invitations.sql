-- 210_staff_invitations.sql
--
-- Inviting a person to the back office: an admin creates an invitation for one
--email, one role and one branch, and the invited person accepts it themselves
--from the sign-in screen with a code and a password of their choosing.
--
-- Why this file exists
--   * 080 built `identity.provision_staff`, which needs an `auth.users` row that
--     does not exist yet and two write permissions the invited person cannot
--     have. So provisioning has always started from an account, and the app has
--     never had a way to create the account: 123 documents that an invitation
--     flow is supposed to do it with the service role. The admin app must never
--     hold a service key, so the flow is inverted here — the invited person
--     creates their own account through Supabase Auth, and the database decides
--     whether that account may become a staff member.
--   * 082 stopped staff activation for exactly this reason and listed what a
--     safe design must contain: a token, an expiration, a verify-before-activate
--     step, and no path that lets anyone who knows a user id activate it. Those
--     four are what this migration adds.
--
-- The rules the database owns
--   1. Only an account whose email is the invited email may accept. The email is
--      the identity, the token is the proof the admin wanted that email invited,
--      and both must hold. Knowing a code is not enough.
--   2. An invitation is pending for seven days and then stops answering, without
--      a cron job: expiry is compared at read time, so no scheduled job can be
--      the reason an old code still works.
--   3. An invitation grants the role it was created with and the branch it was
--      created for, and the creator must hold `admin.staff.write` over that
--      branch — the same scope 209's `identity.can_edit_staff` enforces. Granting
--      `owner` still requires an owner, as 123 already insists for provisioning.
--   4. One auth uid is either a customer or a staff member (188). Every account
--      that signs up is given a customer profile by `identity.handle_new_user`,
--      so accepting an invitation converts the account: the staff insert removes
--      that profile through 188's own trigger. The refusal is for the case the
--      trigger itself refuses — an account with order history — and it gets its
--      own reason instead of a database error.
--   5. Nobody reads or writes the table directly. The project's `ensure_rls`
--      event trigger only covers the `public` schema, so this file enables RLS on
--      the table itself and then deliberately creates no policies: the five
--      functions below are the only doors, each of them SECURITY DEFINER with an
--      empty search path. `identity.admins` is already kept that way.

-- ---------------------------------------------------------------------------
-- 1. The invitation.
-- ---------------------------------------------------------------------------
create table if not exists identity.staff_invitations (
  id            uuid primary key default extensions.gen_random_uuid(),
  email         text not null,
  full_name     text not null,
  role_code     text not null,
  branch_id     uuid references core.branches(id) on delete restrict,
  invited_by    uuid references identity.staff_members(id) on delete set null,
  token         uuid not null unique default extensions.gen_random_uuid(),
  status        text not null default 'pending'
                  check (status in ('pending', 'accepted', 'cancelled')),
  expires_at    timestamptz not null default now() + interval '7 days',
  accepted_at   timestamptz,
  accepted_user_id uuid references auth.users(id) on delete set null,
  created_at    timestamptz not null default now(),
  constraint staff_invitations_email_lowercase check (email = lower(email)),
  constraint staff_invitations_email_shape
    check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  constraint staff_invitations_named check (btrim(full_name) <> '')
);

comment on table identity.staff_invitations is
  'Pending invitations to the back office. The token is the code the invited '
  'person types; the row is kept after it is used as the audit trail.';
comment on column identity.staff_invitations.token is
  'A random uuid shown to the inviter and typed by the invitee. Only pending '
  'invitations answer to it, and it is never returned once the row is used.';
comment on column identity.staff_invitations.status is
  'pending, accepted or cancelled. An expired pending row stays pending and is '
  'reported as expired by the functions that read it.';
comment on column identity.staff_invitations.branch_id is
  'The branch the role is granted in. Null means every branch, which only a '
  'caller with global scope may offer.';

create index if not exists ix_staff_invitations_status
  on identity.staff_invitations (status, expires_at);
create index if not exists ix_staff_invitations_email
  on identity.staff_invitations (email);

-- Locked by its own statement, because the platform trigger only reaches the
-- `public` schema. No policy follows on purpose: a client that could select this
-- table would read every outstanding code, and the five functions below are the
-- only way in.
alter table identity.staff_invitations enable row level security;

-- ---------------------------------------------------------------------------
-- 2. Creating an invitation.
-- ---------------------------------------------------------------------------
create or replace function public.admin_invite_staff(
  p_email text,
  p_full_name text,
  p_role_code text,
  p_branch_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_caller identity.staff_members%rowtype;
  v_role identity.roles%rowtype;
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_name text := btrim(coalesce(p_full_name, ''));
  v_invitation identity.staff_invitations%rowtype;
begin
  if v_uid is null or not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select * into v_caller
    from identity.staff_members
   where user_id = v_uid
     and status = 'active';
  if not found then
    raise exception 'not an active staff member' using errcode = '42501';
  end if;
  if not identity.has_permission('admin.staff.write') then
    raise exception 'missing permission: admin.staff.write' using errcode = '42501';
  end if;

  if v_email = '' or v_email !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_email');
  end if;
  if char_length(v_name) < 2 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_name');
  end if;

  select * into v_role from identity.roles where code = btrim(coalesce(p_role_code, ''));
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'unknown_role');
  end if;

  -- 123 already refuses to hand out the top role to anyone who does not hold it.
  if v_role.code = 'owner' and not exists (
    select 1
      from identity.staff_roles sr
      join identity.roles r on r.id = sr.role_id
     where sr.staff_id = v_caller.id
       and r.code = 'owner'
  ) then
    return jsonb_build_object('ok', false, 'reason', 'owner_only');
  end if;

  if p_branch_id is null then
    if not identity.manages_all_branches() then
      return jsonb_build_object('ok', false, 'reason', 'not_your_branch');
    end if;
  else
    if not exists (select 1 from core.branches where id = p_branch_id) then
      return jsonb_build_object('ok', false, 'reason', 'unknown_branch');
    end if;
    if not identity.can_manage_branch(p_branch_id) then
      return jsonb_build_object('ok', false, 'reason', 'not_your_branch');
    end if;
  end if;

  -- A live invitation for the same email would only confuse the invitee, and a
  -- staff row means the account already exists: neither is a second invitation.
  select * into v_invitation
    from identity.staff_invitations
   where email = v_email
     and status = 'pending'
     and expires_at > now()
   order by created_at desc
   limit 1;
  if found then
    return jsonb_build_object(
      'ok', false, 'reason', 'already_invited', 'invitation_id', v_invitation.id
    );
  end if;

  if exists (select 1 from identity.staff_members where email = v_email) then
    return jsonb_build_object('ok', false, 'reason', 'already_staff');
  end if;

  insert into identity.staff_invitations (
    email, full_name, role_code, branch_id, invited_by
  ) values (
    v_email, v_name, v_role.code, p_branch_id, v_caller.id
  ) returning * into v_invitation;

  perform identity.audit(
    'staff.invite',
    'staff_invitation',
    v_invitation.id,
    null,
    jsonb_build_object(
      'email', v_invitation.email,
      'role', v_invitation.role_code,
      'branch_id', v_invitation.branch_id
    ),
    v_invitation.branch_id
  );

  return jsonb_build_object(
    'ok', true,
    'invitation_id', v_invitation.id,
    'token', v_invitation.token,
    'email', v_invitation.email,
    'full_name', v_invitation.full_name,
    'role_code', v_invitation.role_code,
    'branch_id', v_invitation.branch_id,
    'expires_at', v_invitation.expires_at
  );
end;
$fn$;

comment on function public.admin_invite_staff(text, text, text, uuid) is
  'Create a pending invitation for one email, role and branch. Requires '
  'admin.staff.write over the branch. Returns the token exactly once, to the '
  'caller who made it.';

-- ---------------------------------------------------------------------------
-- 3. What the invite dialog may offer.
--
-- The role screen reads `admin_roles` and the branch screen reads `admin_branches`,
-- and neither is open to an account that only manages staff: a manager could
-- write an invitation and then find the pickers empty. This answers the same two
-- catalogues, cut to what this caller may actually hand out, so the dialog cannot
-- offer a choice the create step would refuse.
-- ---------------------------------------------------------------------------
create or replace function public.admin_staff_invite_options()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_staff_id uuid;
  v_global boolean;
begin
  if v_uid is null or not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('admin.staff.write') then
    raise exception 'missing permission: admin.staff.write' using errcode = '42501';
  end if;

  select id into v_staff_id
    from identity.staff_members
   where user_id = v_uid
     and status = 'active';
  v_global := identity.manages_all_branches();

  return jsonb_build_object(
    'ok', true,
    -- 123 keeps the top role with the owners; the create step refuses it for
    -- anyone else, so it is not offered here either.
    'roles', coalesce((
      select jsonb_agg(jsonb_build_object(
        'code', r.code,
        'name_ar', r.name_ar,
        'name_en', r.name_en
      ) order by r.code)
      from identity.roles r
      where r.code <> 'owner' or exists (
        select 1
          from identity.staff_roles sr
          join identity.roles or_ on or_.id = sr.role_id
         where sr.staff_id = v_staff_id
           and or_.code = 'owner'
      )
    ), '[]'::jsonb),
    'branches', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', b.id,
        'name_ar', b.name_ar,
        'name_en', b.name_en
      ) order by b.code)
      from core.branches b
      where b.is_active
        and (v_global or exists (
          select 1 from identity.staff_roles sr
           where sr.staff_id = v_staff_id
             and sr.branch_id = b.id
        ))
    ), '[]'::jsonb),
    -- An invitation with no branch is a grant over every branch, so only a
    -- caller who holds one may choose it.
    'can_offer_any_branch', v_global
  );
end;
$fn$;

comment on function public.admin_staff_invite_options() is
  'The roles and branches one caller may put into an invitation. Requires '
  'admin.staff.write; the owner role and the no-branch choice appear only for a '
  'caller who can actually grant them.';

-- ---------------------------------------------------------------------------
-- 4. The list an admin manages.
-- ---------------------------------------------------------------------------
create or replace function public.admin_staff_invitations()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_caller_id uuid;
begin
  if v_uid is null or not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('admin.staff.read') then
    raise exception 'missing permission: admin.staff.read' using errcode = '42501';
  end if;

  -- The directory itself is not cut by branch (142 has always answered with
  -- every staff row to whoever holds admin.staff.read), so neither is this list.
  -- A code is a different kind of value: it is what lets a person in, so it
  -- travels only to the account that wrote it, and to whoever manages every
  -- branch and may therefore re-issue one anyway.
  select id into v_caller_id
    from identity.staff_members
   where user_id = v_uid
     and status = 'active';

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', si.id,
      'email', si.email,
      'full_name', si.full_name,
      'role_code', si.role_code,
      'role_name_ar', r.name_ar,
      'role_name_en', r.name_en,
      'branch_id', si.branch_id,
      'branch_name_ar', b.name_ar,
      'branch_name_en', b.name_en,
      -- The stored state stays what happened; the state shown adds the clock.
      'status', case
                   when si.status = 'pending' and si.expires_at <= now()
                     then 'expired'
                   else si.status
                 end,
      'invited_at', si.created_at,
      'expires_at', si.expires_at,
      'accepted_at', si.accepted_at,
      'invited_by', si.invited_by,
      'invited_by_name', coalesce(inv.full_name, ''),
      -- And a code is worthless once the row has been used.
      'token', case
                 when si.status = 'pending'
                      and si.expires_at > now()
                      and (si.invited_by = v_caller_id or identity.manages_all_branches())
                   then si.token
                 end
    ) order by si.created_at desc)
    from identity.staff_invitations si
    left join identity.roles r on r.code = si.role_code
    left join core.branches b on b.id = si.branch_id
    left join identity.staff_members inv on inv.id = si.invited_by
  ), '[]'::jsonb);
end;
$fn$;

comment on function public.admin_staff_invitations() is
  'Every invitation with its live state. Requires admin.staff.read; the token is '
  'only carried for the caller who wrote the invitation, or one who manages every '
  'branch, and only while the row is still pending.';

-- ---------------------------------------------------------------------------
-- 5. Cancelling one.
-- ---------------------------------------------------------------------------
create or replace function public.admin_cancel_invitation(p_invitation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_invitation identity.staff_invitations%rowtype;
begin
  if v_uid is null or not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('admin.staff.write') then
    raise exception 'missing permission: admin.staff.write' using errcode = '42501';
  end if;

  select * into v_invitation
    from identity.staff_invitations
   where id = p_invitation_id;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if v_invitation.status <> 'pending' then
    return jsonb_build_object('ok', false, 'reason', 'not_pending');
  end if;

  -- The same scope that let the invitation be written lets it be withdrawn.
  if v_invitation.branch_id is null then
    if not identity.manages_all_branches() then
      raise exception 'out of scope' using errcode = '42501';
    end if;
  elsif not identity.can_manage_branch(v_invitation.branch_id) then
    raise exception 'out of scope' using errcode = '42501';
  end if;

  update identity.staff_invitations
     set status = 'cancelled'
   where id = v_invitation.id
     and status = 'pending';

  perform identity.audit(
    'staff.invite.cancel',
    'staff_invitation',
    v_invitation.id,
    jsonb_build_object('status', v_invitation.status),
    jsonb_build_object('status', 'cancelled', 'email', v_invitation.email),
    v_invitation.branch_id
  );

  return jsonb_build_object('ok', true);
end;
$fn$;

comment on function public.admin_cancel_invitation(uuid) is
  'Withdraw a pending invitation. The row is kept so the trail shows what was '
  'offered and then taken back.';

-- ---------------------------------------------------------------------------
-- 6. What the invited person sees before they have an account.
-- ---------------------------------------------------------------------------
create or replace function public.admin_invitation_lookup(p_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_invitation identity.staff_invitations%rowtype;
begin
  if p_token is null then
    return jsonb_build_object('ok', false, 'reason', 'unknown');
  end if;

  select * into v_invitation from identity.staff_invitations where token = p_token;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'unknown');
  end if;

  if v_invitation.status = 'accepted' then
    return jsonb_build_object('ok', false, 'reason', 'accepted');
  end if;
  if v_invitation.status = 'cancelled' then
    return jsonb_build_object('ok', false, 'reason', 'cancelled');
  end if;
  if v_invitation.expires_at <= now() then
    return jsonb_build_object('ok', false, 'reason', 'expired');
  end if;

  -- An anonymous answer, so the invited person can tell which email to sign up
  -- with. Nothing else about the account is revealed: no ids, no staff rows.
  -- The names are read where they live rather than joined, because a code is one
  -- row of this table and the invitation record is already in hand.
  return jsonb_build_object(
    'ok', true,
    'email', v_invitation.email,
    'full_name', v_invitation.full_name,
    'role_code', v_invitation.role_code,
    'role_name_ar', (select name_ar from identity.roles where code = v_invitation.role_code),
    'role_name_en', (select name_en from identity.roles where code = v_invitation.role_code),
    'branch_name_ar', (select name_ar from core.branches where id = v_invitation.branch_id),
    'branch_name_en', (select name_en from core.branches where id = v_invitation.branch_id),
    'expires_at', v_invitation.expires_at
  );
end;
$fn$;

comment on function public.admin_invitation_lookup(uuid) is
  'What a code invites, for the sign-in screen that has no session yet. Answers '
  'the email and the role only, and only while the invitation is live.';

-- ---------------------------------------------------------------------------
-- 7. Accepting one.
-- ---------------------------------------------------------------------------
create or replace function public.admin_accept_invitation(p_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_invitation identity.staff_invitations%rowtype;
  v_role identity.roles%rowtype;
  v_staff_id uuid;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select lower(email) into v_email from auth.users where id = v_uid;
  if v_email is null then
    return jsonb_build_object('ok', false, 'reason', 'no_email');
  end if;

  select * into v_invitation from identity.staff_invitations where token = p_token;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'unknown');
  end if;
  if v_invitation.status = 'accepted' then
    return jsonb_build_object('ok', false, 'reason', 'accepted');
  end if;
  if v_invitation.status = 'cancelled' then
    return jsonb_build_object('ok', false, 'reason', 'cancelled');
  end if;
  if v_invitation.expires_at <= now() then
    return jsonb_build_object('ok', false, 'reason', 'expired');
  end if;

  -- The email of the session is the invited email. A leaked code typed by
  -- someone else buys them nothing.
  if v_email <> v_invitation.email then
    return jsonb_build_object('ok', false, 'reason', 'email_mismatch');
  end if;

  -- 188 keeps the two identities apart: the staff insert itself removes the
  -- customer profile that `identity.handle_new_user` gave this account when it
  -- signed up, and that removal is refused when the person already owns orders.
  -- Writing inside one block is what makes the refusal leave nothing behind.
  if exists (select 1 from identity.staff_members where user_id = v_uid) then
    return jsonb_build_object('ok', false, 'reason', 'already_staff');
  end if;
  if exists (select 1 from identity.staff_members where email = v_invitation.email) then
    return jsonb_build_object('ok', false, 'reason', 'already_staff');
  end if;

  select * into v_role from identity.roles where code = v_invitation.role_code;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'unknown_role');
  end if;

  begin
    insert into identity.staff_members (
      user_id, status, full_name, email, invited_by, invited_at, accepted_at
    ) values (
      v_uid, 'active', v_invitation.full_name, v_invitation.email,
      v_invitation.invited_by, v_invitation.created_at, now()
    ) returning id into v_staff_id;

    -- 004 makes (staff_id, role_id) the primary key: one role per account, and
    -- branch_id only says which branch it is held in. The unique index over the
    -- scope is an expression index on coalesce(branch_id, zero-uuid), so naming
    -- the plain branch_id column here would be refused with 42P10.
    insert into identity.staff_roles (staff_id, role_id, branch_id, granted_by)
    values (
      v_staff_id, v_role.id, v_invitation.branch_id, v_invitation.invited_by
    )
    on conflict (staff_id, role_id) do nothing;
  exception when foreign_key_violation or check_violation then
    return jsonb_build_object('ok', false, 'reason', 'customer_history');
  end;

  update identity.staff_invitations
     set status = 'accepted', accepted_at = now(), accepted_user_id = v_uid
   where id = v_invitation.id;

  perform identity.audit(
    'staff.invite.accept',
    'staff_member',
    v_staff_id,
    null,
    jsonb_build_object(
      'invitation_id', v_invitation.id,
      'email', v_invitation.email,
      'role', v_invitation.role_code,
      'branch_id', v_invitation.branch_id
    ),
    v_invitation.branch_id
  );

  return jsonb_build_object(
    'ok', true,
    'staff_id', v_staff_id,
    'full_name', v_invitation.full_name,
    'email', v_invitation.email,
    'role_code', v_invitation.role_code,
    'branch_id', v_invitation.branch_id
  );
end;
$fn$;

comment on function public.admin_accept_invitation(uuid) is
  'Turn the signed-in account into the staff member the invitation promised, when '
  'its email is the invited email and the code is still live. This is the '
  'verify-before-activate step 082 asked for.';

-- ---------------------------------------------------------------------------
-- 8. Grants.
-- ---------------------------------------------------------------------------
revoke all on function public.admin_invite_staff(text, text, text, uuid)
  from public, anon;
grant execute on function public.admin_invite_staff(text, text, text, uuid)
  to authenticated;

revoke all on function public.admin_staff_invite_options() from public, anon;
grant execute on function public.admin_staff_invite_options() to authenticated;

revoke all on function public.admin_staff_invitations() from public, anon;
grant execute on function public.admin_staff_invitations() to authenticated;

revoke all on function public.admin_cancel_invitation(uuid) from public, anon;
grant execute on function public.admin_cancel_invitation(uuid) to authenticated;

-- The lookup is the one door an account-less visitor needs: it answers only what
-- a code already promises, and the accept step still requires a session on the
-- invited email.
revoke all on function public.admin_invitation_lookup(uuid) from public;
grant execute on function public.admin_invitation_lookup(uuid) to anon, authenticated;

revoke all on function public.admin_accept_invitation(uuid) from public, anon;
grant execute on function public.admin_accept_invitation(uuid) to authenticated;

-- `public.admin_staff()` is not touched here: 209 already returns every column
-- the directory needs, including `avatar_url`, and a second copy of its body in
-- this file would be a second place to keep in step. Pending invitations have
-- their own list, because an invited person is not yet a staff row.

notify pgrst, 'reload schema';
