begin;
insert into core.branches(id,brand_id,code,name_ar,name_en,address) select 'bca00000-0000-4000-8000-000000000001',id,'CANCEL-CUTOFF-TEST','اختبار','Cutoff test','test' from core.brands limit 1;
insert into auth.users(id,email) values ('bca00000-0000-4000-8000-000000000021','cutoff-admin@test.local'),('bca00000-0000-4000-8000-000000000023','cutoff-customer@test.local');
insert into identity.staff_members(id,user_id,status,full_name,email) values ('bca00000-0000-4000-8000-000000000031','bca00000-0000-4000-8000-000000000021','active','Cutoff test','cutoff-admin@test.local');
insert into identity.staff_roles(staff_id,role_id,branch_id) select 'bca00000-0000-4000-8000-000000000031',id,null from identity.roles where code='owner';
insert into floor.tables(id,branch_id,name,area,capacity) select ('bca00000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'bca00000-0000-4000-8000-000000000001','Cutoff '||n,'hall',4 from generate_series(11,15) n;
insert into floor.reservations(id,branch_id,table_id,user_id,source,status,customer_name,party_size,reserved_for,reserved_until,duration_minutes)
select ('bca00000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'bca00000-0000-4000-8000-000000000001',('bca00000-0000-4000-8000-'||lpad((n-30)::text,12,'0'))::uuid,'bca00000-0000-4000-8000-000000000023','customer','confirmed','Test',2,now()+make_interval(mins=>m),now()+make_interval(mins=>m+30),30 from (values (41,30),(42,60),(43,120),(44,720),(45,2880)) v(n,m);
insert into floor.customer_event_requests(id,user_id,branch_id,occasion_type,occasion_date,preferred_start_at,preferred_end_at,guest_count,requested_space_type,customer_name,status,reservation_id)
select ('bca00000-0000-4000-8000-'||lpad((n+10)::text,12,'0'))::uuid,user_id,branch_id,'birthday',reserved_for::date,reserved_for,reserved_until,2,'table','Test','confirmed',id from floor.reservations cross join (values (44),(45)) v(n) where id=('bca00000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
update floor.reservations set linked_event_id=('bca00000-0000-4000-8000-'||lpad((n+10)::text,12,'0'))::uuid from (values (44),(45)) v(n) where id=('bca00000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"bca00000-0000-4000-8000-000000000021","role":"authenticated"}',true);
do $$ declare v jsonb; begin
 v:=public.admin_set_reservation_cancellation_policy('bca00000-0000-4000-8000-000000000001',60,1440);
 if v->>'ok'<>'true' then raise exception 'save failed'; end if;
 v:=public.admin_get_reservation_cancellation_policy('bca00000-0000-4000-8000-000000000001');
 if (v->>'table_cutoff_minutes')::int<>60 or (v->>'event_cutoff_minutes')::int<>1440 then raise exception 'readback failed'; end if;
 if public.admin_set_reservation_cancellation_policy('bca00000-0000-4000-8000-000000000001',null,1440)->>'ok'<>'false' then raise exception 'null accepted'; end if;
 if public.admin_set_reservation_cancellation_policy('bca00000-0000-4000-8000-000000000001',-1,1440)->>'ok'<>'false' then raise exception 'negative accepted'; end if;
 if public.cancel_my_reservation('bca00000-0000-4000-8000-000000000043') then raise exception 'other owner allowed'; end if;
end $$;
select set_config('request.jwt.claims','{"sub":"bca00000-0000-4000-8000-000000000023","role":"authenticated"}',true);
do $$ declare v jsonb; begin
 begin
 perform public.admin_set_reservation_cancellation_policy('bca00000-0000-4000-8000-000000000001',0,0);
 raise exception 'customer allowed settings write';
 exception when insufficient_privilege then null; end;
 if public.cancel_my_reservation('bca00000-0000-4000-8000-000000000041') then raise exception 'inside cutoff accepted'; end if;
 if public.cancel_my_reservation('bca00000-0000-4000-8000-000000000042') then raise exception 'exact cutoff accepted'; end if;
 if not public.cancel_my_reservation('bca00000-0000-4000-8000-000000000043') then raise exception 'outside cutoff denied'; end if;
 if public.cancel_my_reservation('bca00000-0000-4000-8000-000000000043') then raise exception 'duplicate cancellation accepted'; end if;
 if public.cancel_my_customer_event_request('bca00000-0000-4000-8000-000000000054') then raise exception 'event inside cutoff accepted'; end if;
 if public.cancel_my_reservation('bca00000-0000-4000-8000-000000000044') then raise exception 'event bypass via reservation'; end if;
 if not public.cancel_my_customer_event_request('bca00000-0000-4000-8000-000000000055') then raise exception 'event outside cutoff denied'; end if;
 select value into v from jsonb_array_elements(public.list_my_reservations()) where value->>'id'='bca00000-0000-4000-8000-000000000044';
 if v->>'customer_can_cancel'<>'false' or not(v ? 'occasion_name') then raise exception 'reservation contract incorrect'; end if;
 select value into v from jsonb_array_elements(public.list_my_customer_event_requests()) where value->>'id'='bca00000-0000-4000-8000-000000000055';
 if v->>'status'<>'cancelled' or not(v ? 'quoted_space_image_url') then raise exception 'event contract incorrect'; end if;
end $$;
reset role;
do $$ begin
 if (select status from floor.reservations where id='bca00000-0000-4000-8000-000000000045')<>'cancelled' then raise exception 'event/reservation not atomic'; end if;
end $$;
rollback;
select 'PASS: settings read/write, invalid input, customer permission, ownership, cutoff boundary, repeat cancellation, event cutoff and linked reservation, response contracts; all fixtures rolled back' as result;

