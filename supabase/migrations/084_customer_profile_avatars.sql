-- 084_customer_profile_avatars.sql
--
-- Private, per-customer profile photos.
--
-- Before this, `identity.profiles.avatar_url` existed (003_identity_01_profiles.sql)
-- but nothing ever wrote it and no Storage bucket existed, so a photo chosen in
-- the app lived only as a Uint8List in ProfileCubit and vanished with the
-- process. This migration adds the server side so a photo chosen on one device
-- follows the customer to another.
--
-- Design
-- ------
-- * Bucket `avatars` is PRIVATE. A public bucket would hand every customer's
--   photo out to anyone holding the object path, so display must go through a
--   short-lived signed URL instead.
-- * Objects live at `<auth.uid()>/avatar.<ext>`. The first folder segment is the
--   owner, which is what the policies key on.
-- * `identity.profiles.avatar_url` stores that PATH, never a signed URL: a signed
--   URL expires, and persisting one would leave the column holding a dead link
--   after an hour.
-- * `profiles_update_own` (019_rls_01_identity.sql) already lets a customer
--   update their own row, so no profile-table policy is changed here.
--
-- Policy shape
-- ------------
-- `(storage.foldername(name))[1] = (select auth.uid()::text)` is the owner
-- check. `storage.foldername` is SECURITY INVOKER, so `authenticated` must be
-- able to execute it or every policy here would fail with 42501; that grant is
-- already in place on this project and is asserted in
-- supabase/tests/avatar_storage_policies_test.sql rather than assumed.
--
-- `anon` is deliberately absent from every policy. `anon` does hold table-level
-- privileges on storage.objects, so RLS is the only thing keeping guests out;
-- with zero anon policies the private bucket denies by default.
--
-- Nothing here touches customer data or any existing policy.

-- ---------------------------------------------------------------------------
-- Bucket
-- ---------------------------------------------------------------------------
-- 5 MiB is generous for a 600px avatar that the client already downsizes.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

-- NOTE: there is deliberately no `comment on bucket` here. That syntax belongs
-- to the Storage management API and is not accepted by the database, so the
-- first apply attempt aborted on it. The intent is recorded here instead.

-- ---------------------------------------------------------------------------
-- Object policies, scoped to the caller's own folder.
--
-- Re-created rather than updated so the migration is re-runnable and the text
-- here is always the definition in force.
-- ---------------------------------------------------------------------------
drop policy if exists "avatars_select_own_folder" on storage.objects;
create policy "avatars_select_own_folder"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

drop policy if exists "avatars_insert_own_folder" on storage.objects;
create policy "avatars_insert_own_folder"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

drop policy if exists "avatars_update_own_folder" on storage.objects;
create policy "avatars_update_own_folder"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

drop policy if exists "avatars_delete_own_folder" on storage.objects;
create policy "avatars_delete_own_folder"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

-- ---------------------------------------------------------------------------
-- The bucket must stay private. This is belt and braces for the public flag:
-- storage.get_public_url resolves against buckets.public, so flipping it to true
-- would make every avatar readable without a session. The dashboard setting and
-- this row are the same value, so the row is asserted in the policy tests.
-- ---------------------------------------------------------------------------
update storage.buckets set public = false where id = 'avatars';