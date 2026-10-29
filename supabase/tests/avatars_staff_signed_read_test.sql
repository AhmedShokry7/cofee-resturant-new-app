-- avatars_staff_signed_read_test.sql
-- سلوك سياسة قراءة الصور في دلو avatars بعد 208_avatars_staff_signed_read.sql.
--
-- يجري داخل معاملة واحدة تُلفّ، على المشروع الحيّ. يثبت أربعة أشياء:
--   1. الموظف الذي يملك customers.read يرى صورة عميل آخر (وهذا ما كان يعيد
--      Placeholder في لوحة الأدمن).
--   2. العميل لا يرى صورة جاره، والموظف بلا الصلاحية لا يرى شيئًا.
--   3. السياسة جديدة للقراءة فقط: لا أحد يكتب صورة في مجلد عميل، وسياسة الحذف
--      ما زالت على مجلد صاحبه لم يمسّها التوسيع.
--   4. الوظيفة الميتة من 152 لم تعد في pg_proc، والدلو ما زال خاصًا.

\set ON_ERROR_STOP on

begin;

-- ---------------------------------------------------------------------------
-- بيانات الاختبار: موظفان، وعميلان لكلٍّ منهما صورة في مجلده.
-- ---------------------------------------------------------------------------
insert into auth.users (id, email)
values
  ('cafe0000-0000-4000-8000-000000000001', 'avatars-manager@test.local'),
  ('cafe0000-0000-4000-8000-000000000002', 'avatars-cashier@test.local'),
  ('cafe0000-0000-4000-8000-000000000003', 'avatars-cust-a@test.local'),
  ('cafe0000-0000-4000-8000-000000000004', 'avatars-cust-b@test.local');

insert into identity.staff_members (id, user_id, status, full_name, email)
values
  ('cafe1000-0000-4000-8000-000000000001', 'cafe0000-0000-4000-8000-000000000001', 'active', 'Manager', 'avatars-manager@test.local'),
  ('cafe1000-0000-4000-8000-000000000002', 'cafe0000-0000-4000-8000-000000000002', 'active', 'Cashier', 'avatars-cashier@test.local');

insert into identity.staff_roles (staff_id, role_id)
select 'cafe1000-0000-4000-8000-000000000001', r.id from identity.roles r where r.code = 'manager';

insert into identity.staff_roles (staff_id, role_id)
select 'cafe1000-0000-4000-8000-000000000002', r.id from identity.roles r where r.code = 'cashier';

-- trigger على auth.users يكتب profiles لكلّ حساب، و188 يحذف صفّ الموظف.
-- مسارا الصورتين داخل مجلد كل عميل، كما يكتبهما تطبيق العميل فعلًا.
update identity.profiles
   set avatar_url = id::text || '/avatar_test.jpg'
 where id in ('cafe0000-0000-4000-8000-000000000003'::uuid,
              'cafe0000-0000-4000-8000-000000000004'::uuid);

insert into storage.objects (bucket_id, name, owner)
values
  ('avatars', 'cafe0000-0000-4000-8000-000000000003/avatar_test.jpg',
   'cafe0000-0000-4000-8000-000000000003'),
  ('avatars', 'cafe0000-0000-4000-8000-000000000004/avatar_test.jpg',
   'cafe0000-0000-4000-8000-000000000004');

-- ---------------------------------------------------------------------------
-- 1. الموظف صاحب customers.read يرى صورة العميل الآخر.
--    هذه هي الحالة التي كانت تُبقي لوحة الأدمن على Placeholder.
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"cafe0000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  if not exists (
    select 1 from storage.objects
     where bucket_id = 'avatars'
       and name = 'cafe0000-0000-4000-8000-000000000003/avatar_test.jpg'
  ) then
    raise exception 'FAIL: a manager with customers.read cannot see the customer avatar';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. العميل لا يرى صورة جاره، وصاحب customers.read يرى صفتيهما معًا.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"cafe0000-0000-4000-8000-000000000004","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v_count int;
begin
  select count(*) into v_count from storage.objects where bucket_id = 'avatars';
  if v_count <> 1 then
    raise exception 'FAIL: customer %s sees %s avatars, expected only their own',
      'cafe0000-0000-4000-8000-000000000004', v_count;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. موظف بلا customers.read (كاشير) لا يرى شيئًا من الدلو.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"cafe0000-0000-4000-8000-000000000002","role":"authenticated","aud":"authenticated"}', true);

do $$
declare v_count int;
begin
  select count(*) into v_count from storage.objects where bucket_id = 'avatars';
  if v_count <> 0 then
    raise exception 'FAIL: a cashier without customers.read sees %s avatars', v_count;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4. القراءة فقط: لا كتابة في مجلد عميل ولا حذف لصورة غيره.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"cafe0000-0000-4000-8000-000000000001","role":"authenticated","aud":"authenticated"}', true);

do $$
begin
  insert into storage.objects (bucket_id, name, owner)
  values ('avatars', 'cafe0000-0000-4000-8000-000000000003/planted.jpg',
          'cafe0000-0000-4000-8000-000000000001');
  raise exception 'FAIL: staff wrote an object into a customer folder';
exception
  when insufficient_privilege then null;
  when others then
    if sqlstate <> '42501' then raise; end if;
end $$;

-- الحذف لا يُجرَّب نداءً: trigger باسم storage.protect_delete (في هذا المشروع)
-- يرفض كل حذف مباشر من جدول storage.objects قبل أن تصل السياسة، فالدلالة تُقرأ
-- من تعريف السياسة نفسها: التوسيع مسّ القراءة وحدها، وبقي الحذف على المجلد.
do $$
begin
  if not exists (
    select 1 from pg_policies
     where schemaname = 'storage' and tablename = 'objects'
       and policyname = 'avatars_delete_own_folder'
       and qual ~ 'auth\.uid\(\)'
       and qual not like '%customers.read%') then
    raise exception 'FAIL: the delete policy stopped being owner-only';
  end if;
  if exists (select 1 from pg_policies
              where schemaname = 'storage' and tablename = 'objects'
                and policyname like 'avatars_%'
                and cmd <> 'SELECT'
                and qual is not null
                and qual like '%customers.read%') then
    raise exception 'FAIL: the customers.read branch leaked into a write policy';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5. الدلو خاص، والوظيفة الميتة راحت، والسياسات أربع لا خامس لها.
-- ---------------------------------------------------------------------------
reset role;

do $$
begin
  if (select public from storage.buckets where id = 'avatars') then
    raise exception 'FAIL: the avatars bucket was made public';
  end if;
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
              where n.nspname = 'public' and p.proname = 'admin_customer_avatar_url') then
    raise exception 'FAIL: admin_customer_avatar_url still lives in pg_proc';
  end if;
  -- The four customer-folder policies. The count is scoped to them because 209
  -- put a staff folder side by side in the same bucket, which would make a bare
  -- 'avatars_%' count a moving target for this file.
  if (select count(*) from pg_policies
         where schemaname = 'storage' and tablename = 'objects'
           and policyname like 'avatars_%own_folder') <> 4 then
    raise exception 'FAIL: expected exactly four customer-folder avatars policies';
  end if;
  if not exists (
    select 1 from pg_policies
     where schemaname = 'storage' and tablename = 'objects'
       and policyname = 'avatars_select_own_folder'
       and cmd = 'SELECT'
       and qual ~ 'auth\.uid\(\)'
       and qual ~ 'customers\.read') then
    raise exception 'FAIL: the select policy lost its owner-or-customers.read shape';
  end if;
  if exists (select 1 from pg_policies
              where schemaname = 'storage' and tablename = 'objects'
                and policyname like 'avatars_%' and roles::text like '%anon%') then
    raise exception 'FAIL: an avatars policy became reachable by anon';
  end if;
end $$;

select 'PASS' as avatars_staff_signed_read;

rollback;
