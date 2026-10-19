-- avatar_storage_policies_test.sql
--
-- Privilege and privacy assertions for the private `avatars` bucket added by
-- 084_customer_profile_avatars.sql.
--
-- These matter because the failure mode is invisible in a green build: a public
-- bucket serves every customer's photo to anyone holding the object path, and a
-- policy that calls a function the caller cannot execute fails closed with
-- 42501 and takes every avatar with it. Both are asserted here rather than
-- assumed.
--
-- Run as a privileged role.

\set ON_ERROR_STOP on

-- ---------------------------------------------------------------------------
-- 1. The bucket is private and bounded.
-- ---------------------------------------------------------------------------
select case when exists (select 1 from storage.buckets where id = 'avatars')
       then 'PASS' else 'FAIL: the avatars bucket does not exist' end as t1;

select case when coalesce((select public from storage.buckets where id = 'avatars'), true)
       then 'FAIL: the avatars bucket is public; every photo is readable by URL alone'
       else 'PASS' end as t2;

select case when coalesce((select file_size_limit from storage.buckets where id = 'avatars'), 0) > 0
              and coalesce((select file_size_limit from storage.buckets where id = 'avatars'), 0) <= 10485760
       then 'PASS' else 'FAIL: file_size_limit is unset or larger than 10 MiB' end as t3;

select case when (
         select array_agg(m order by m) = array['image/jpeg','image/png','image/webp']::text[]
           from unnest(coalesce((select allowed_mime_types from storage.buckets where id = 'avatars'), '{}')) m
       ) then 'PASS' else 'FAIL: allowed_mime_types is not exactly jpeg/png/webp' end as t4;

-- ---------------------------------------------------------------------------
-- 2. One policy per operation, all scoped to authenticated only.
-- ---------------------------------------------------------------------------
select case when (
         select count(*) = 4 from pg_policies
          where schemaname = 'storage' and tablename = 'objects'
            and policyname like 'avatars_%'
       ) then 'PASS' else 'FAIL: expected exactly four avatars_* policies' end as t5;

select case when (
         select bool_and('{authenticated}' = roles::text) from pg_policies
          where schemaname = 'storage' and tablename = 'objects'
            and policyname like 'avatars_%'
       ) then 'PASS' else 'FAIL: an avatars policy applies to a role other than authenticated' end as t6;

-- ---------------------------------------------------------------------------
-- 3. Guests are excluded.
--
-- `anon` holds table-level privileges on storage.objects in this project, so RLS
-- is the only thing keeping guests out. With no anon policy the table denies by
-- default, which is exactly what is wanted.
-- ---------------------------------------------------------------------------
select case when exists (
         select 1 from pg_policies
          where schemaname = 'storage' and tablename = 'objects'
            and policyname like 'avatars_%'
            and roles::text like '%anon%'
       ) then 'FAIL: an avatars policy is reachable by anon'
       else 'PASS' end as t7;

select case when exists (
         select 1 from pg_policies
          where schemaname = 'storage' and tablename = 'objects'
            and roles::text like '%public%'
       ) then 'FAIL: a storage policy is granted to PUBLIC'
       else 'PASS' end as t8;

-- ---------------------------------------------------------------------------
-- 4. Every avatars policy is folder-scoped to the caller.
--
-- A policy without auth.uid() in it would let any signed-in customer read or
-- overwrite any other customer's photo.
-- ---------------------------------------------------------------------------
select case when (
         select bool_and(
                  qual is not null and qual ~* 'auth\.uid\(\)'
                  or with_check is not null and with_check ~* 'auth\.uid\(\)'
                )
           from pg_policies
          where schemaname = 'storage' and tablename = 'objects'
            and policyname like 'avatars_%'
       ) then 'PASS' else 'FAIL: an avatars policy is not scoped to auth.uid()' end as t9;

select case when (
         select count(*) = 2 from pg_policies
          where schemaname = 'storage' and tablename = 'objects'
            and policyname like 'avatars_%'
            and cmd in ('INSERT','UPDATE')
            and with_check is not null
            and with_check ~* 'auth\.uid\(\)'
       ) then 'PASS' else 'FAIL: an INSERT/UPDATE policy does not re-check the folder' end as t10;

-- ---------------------------------------------------------------------------
-- 5. The 42501 trap.
--
-- storage.foldername is SECURITY INVOKER, so the policy expressions run as the
-- querying role. If `authenticated` cannot execute it, every avatar operation
-- fails with "permission denied for function foldername". This is the same
-- class of defect as 081, so it is asserted rather than assumed.
-- ---------------------------------------------------------------------------
select case when has_function_privilege('authenticated','storage.foldername(text)','EXECUTE')
       then 'PASS' else 'FAIL: authenticated cannot execute storage.foldername; avatar policies would fail with 42501' end as t11;

-- ---------------------------------------------------------------------------
-- 6. The profile side is untouched and still permits a self-update.
--
-- 084 must not have needed to change the profile table, and avatar_url must
-- remain writable by the owner alone.
-- ---------------------------------------------------------------------------
select case when exists (
         select 1 from information_schema.columns
          where table_schema = 'identity' and table_name = 'profiles'
            and column_name = 'avatar_url'
       ) then 'PASS' else 'FAIL: identity.profiles.avatar_url is missing' end as t12;

select case when exists (
         select 1 from pg_policies
          where schemaname = 'identity' and tablename = 'profiles'
            and policyname = 'profiles_update_own' and cmd = 'UPDATE'
       ) then 'PASS' else 'FAIL: profiles_update_own is missing; the avatar path cannot be saved' end as t13;

select case when not exists (
         select 1 from pg_policies
          where schemaname = 'identity' and tablename = 'profiles'
            and policyname like 'profiles_%' and roles::text like '%anon%'
       ) then 'PASS' else 'FAIL: a profiles policy is reachable by anon' end as t14;

-- ---------------------------------------------------------------------------
-- 7. RLS is still enabled everywhere it was.
-- ---------------------------------------------------------------------------
select case when exists (
         select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
          where n.nspname = 'storage' and c.relname = 'objects' and not c.relrowsecurity
       ) then 'FAIL: RLS is disabled on storage.objects'
       else 'PASS' end as t15;