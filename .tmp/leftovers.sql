select jsonb_build_object(
 'test_fixture_users', (select count(*) from auth.users where id::text like '6%' or email like 'cdg-%@test.local' or email like 'sg-%@test.local'),
 'test_fixture_profiles', (select count(*) from identity.profiles where id::text like '6%' or email like 'cdg-%@test.local' or email like 'sg-%@test.local'),
 'test_fixture_staff', (select count(*) from identity.staff_members where id::text like '6%' or email like 'cdg-%@test.local' or email like 'sg-%@test.local'),
 'live_staff', (select count(*) from identity.staff_members),
 'live_profiles', (select count(*) from identity.profiles),
 'live_roles', (select count(*) from identity.roles),
 'live_permissions', (select count(*) from identity.permissions),
 'max_version', (select max(version) from supabase_migrations.schema_migrations),
 'v269', (select count(*) from supabase_migrations.schema_migrations where version='269')
) as state;