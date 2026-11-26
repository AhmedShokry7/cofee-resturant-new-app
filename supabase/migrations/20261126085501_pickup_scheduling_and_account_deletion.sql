-- Branch scheduling uses the existing core.branches.hours and timezone settings.
-- Repeated weekly windows, dated closures/overrides, and a per-window capacity
-- are stored once and locked when an order is placed.
create table if not exists core.branch_pickup_windows (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references core.branches(id) on delete cascade,
  weekday smallint not null check (weekday between 0 and 6),
  opens_at time not null,
  closes_at time not null,
  slot_minutes smallint not null default 15 check (slot_minutes between 5 and 240),
  capacity smallint not null default 8 check (capacity between 1 and 500),
  prep_minutes smallint not null default 15 check (prep_minutes between 0 and 480),
  enabled boolean not null default true,
  check (opens_at < closes_at)
);
create index if not exists branch_pickup_windows_branch_day on core.branch_pickup_windows(branch_id,weekday) where enabled;
alter table core.branches add column if not exists time_zone text not null default 'Asia/Riyadh';
create table if not exists core.branch_pickup_exceptions (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references core.branches(id) on delete cascade,
  exception_date date not null,
  closed boolean not null default true,
  opens_at time,
  closes_at time,
  slot_minutes smallint check (slot_minutes between 5 and 240),
  capacity smallint check (capacity between 1 and 500),
  unique(branch_id,exception_date),
  check (closed or (opens_at is not null and closes_at is not null and opens_at < closes_at))
);
alter table orders.orders add column if not exists scheduled_pickup_at timestamptz;
-- Preserve order headers and their financial children if a profile is deleted.
alter table orders.orders alter column user_id drop not null;
do $$ declare c record; begin
 for c in select conname from pg_constraint where conrelid='orders.orders'::regclass and confrelid='identity.profiles'::regclass and contype='f' loop
  execute format('alter table orders.orders drop constraint %I',c.conname);
 end loop;
end $$;
alter table orders.orders add constraint orders_profile_user_id_fk
  foreign key(user_id) references identity.profiles(id) on delete set null;

-- Keep event requests, reservations, and paid subscription history while
-- unlinking the deleted profile. Future commitments are cancelled atomically.
alter table floor.customer_event_requests alter column user_id drop not null;
do $$ declare c record; begin
 for c in select conname from pg_constraint where conrelid='floor.customer_event_requests'::regclass and confrelid='auth.users'::regclass and contype='f' loop
  execute format('alter table floor.customer_event_requests drop constraint %I',c.conname);
 end loop;
end $$;
alter table floor.customer_event_requests add constraint customer_event_requests_user_id_fk
  foreign key(user_id) references auth.users(id) on delete set null;

alter table subscriptions.subscriptions alter column user_id drop not null;
do $$ declare c record; begin
 for c in select conname from pg_constraint where conrelid='subscriptions.subscriptions'::regclass and confrelid='identity.profiles'::regclass and contype='f' loop
  execute format('alter table subscriptions.subscriptions drop constraint %I',c.conname);
 end loop;
end $$;
alter table subscriptions.subscriptions add constraint subscriptions_profile_user_id_fk
  foreign key(user_id) references identity.profiles(id) on delete set null;

alter table subscriptions.customer_product_subscriptions alter column user_id drop not null;
do $$ declare c record; begin
 for c in select conname from pg_constraint where conrelid='subscriptions.customer_product_subscriptions'::regclass and confrelid='auth.users'::regclass and contype='f' loop
  execute format('alter table subscriptions.customer_product_subscriptions drop constraint %I',c.conname);
 end loop;
end $$;
alter table subscriptions.customer_product_subscriptions add constraint customer_product_subscriptions_user_id_fk
  foreign key(user_id) references auth.users(id) on delete set null;

alter table subscriptions.customer_product_subscription_runs alter column user_id drop not null;
do $$ declare c record; begin
 for c in select conname from pg_constraint where conrelid='subscriptions.customer_product_subscription_runs'::regclass and confrelid='auth.users'::regclass and contype='f' loop
  execute format('alter table subscriptions.customer_product_subscription_runs drop constraint %I',c.conname);
 end loop;
end $$;
alter table subscriptions.customer_product_subscription_runs add constraint customer_product_subscription_runs_user_id_fk
  foreign key(user_id) references auth.users(id) on delete set null;

create or replace function identity.handle_customer_profile_deletion()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 update orders.orders set user_id=null,customer_note='',delivery_address_snapshot=coalesce(delivery_address_snapshot,'{}'::jsonb)-'label'-'details'-'latitude'-'longitude'-'address'-'recipient_name'-'phone'-'contact_name'-'contact_phone' where user_id=old.id;
 update floor.customer_event_requests set user_id=null,customer_name='Deleted customer',customer_phone='',customer_note=null,status=case when status in ('pending','quoted','confirmed') then 'cancelled' else status end,cancelled_at=case when status in ('pending','quoted','confirmed') then now() else cancelled_at end where user_id=old.id;
 update floor.reservations set user_id=null,customer_name='Deleted customer',customer_phone='',status=case when status in ('pending','approved','confirmed') then 'cancelled' else status end,cancelled_at=case when status in ('pending','approved','confirmed') then now() else cancelled_at end,cancellation_reason=case when status in ('pending','approved','confirmed') then 'Customer account deleted' else cancellation_reason end where user_id=old.id;
 update subscriptions.subscriptions set user_id=null,status=case when status='active' then 'cancelled' else status end,auto_renew=false,updated_at=now() where user_id=old.id;
 update subscriptions.customer_product_subscription_runs set user_id=null,status=case when status='pending' then 'skipped' else status end,error=case when status='pending' then 'Customer account deleted' else error end where user_id=old.id;
 update subscriptions.customer_product_subscriptions set user_id=null,status=case when status in ('active','paused') then 'cancelled' else status end,next_run_at=null,cancelled_at=case when status in ('active','paused') then now() else cancelled_at end,updated_at=now() where user_id=old.id;
 return old;
end $$;
drop trigger if exists anonymize_customer_on_profile_delete on identity.profiles;
create trigger anonymize_customer_on_profile_delete before delete on identity.profiles for each row execute function identity.handle_customer_profile_deletion();
create table if not exists orders.pickup_slot_capacity (
  branch_id uuid not null references core.branches(id) on delete cascade,
  slot_start timestamptz not null,
  occupied integer not null default 0 check(occupied >= 0),
  primary key(branch_id,slot_start)
);
alter table orders.pickup_slot_capacity enable row level security;
revoke all on orders.pickup_slot_capacity from public,anon,authenticated;

create table if not exists identity.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  -- Keep the request record when auth.users is removed; it contains only the
  -- subject UUID and lifecycle metadata, never credentials or contact data.
  user_id uuid not null unique,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  last_error text,
  status text not null default 'pending' check(status in ('pending','processing','completed','rejected')),
  created_at timestamptz not null default now(),
  processed_at timestamptz,
  resolution_note text
);
alter table identity.account_deletion_requests enable row level security;
revoke all on identity.account_deletion_requests from public,anon,authenticated;

create or replace function public.request_account_deletion()
returns uuid language plpgsql security definer set search_path='' as $$
declare v_uid uuid := auth.uid(); v_id uuid;
begin
 if v_uid is null then raise insufficient_privilege; end if;
 insert into identity.account_deletion_requests(user_id) values(v_uid)
 on conflict(user_id) do update set status='pending',created_at=now(),processed_at=null,resolution_note=null
 where identity.account_deletion_requests.status='rejected'
 returning id into v_id;
 if v_id is null then select id into v_id from identity.account_deletion_requests where user_id=v_uid; end if;
 return v_id;
end $$;
create or replace function public.my_account_deletion_request()
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce((select jsonb_build_object('id',id,'status',status,'created_at',created_at,'processed_at',processed_at,'resolution_note',resolution_note) from identity.account_deletion_requests where user_id=auth.uid()),'null'::jsonb)
$$;
revoke all on function public.request_account_deletion(),public.my_account_deletion_request() from public,anon;
grant execute on function public.request_account_deletion(),public.my_account_deletion_request() to authenticated;

-- Admin-only access is mediated by these RPCs; end users can only create and
-- read their own request through the two functions above.
create or replace function public.admin_pickup_schedule(p_branch uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not identity.has_permission('settings.write') or not identity.can_manage_branch(p_branch) then raise insufficient_privilege; end if;
 return jsonb_build_object(
  'time_zone',(select time_zone from core.branches where id=p_branch),
  'windows',coalesce((select jsonb_agg(to_jsonb(w) order by weekday,opens_at) from core.branch_pickup_windows w where branch_id=p_branch),'[]'::jsonb),
  'exceptions',coalesce((select jsonb_agg(to_jsonb(e) order by exception_date) from core.branch_pickup_exceptions e where branch_id=p_branch and exception_date>=current_date),'[]'::jsonb)
 );
end $$;

create or replace function public.admin_set_branch_time_zone(p_branch uuid,p_time_zone text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not identity.has_permission('settings.write') or not identity.can_manage_branch(p_branch) then raise insufficient_privilege; end if;
 if not exists(select 1 from pg_catalog.pg_timezone_names where name=p_time_zone) then raise exception 'invalid time zone'; end if;
 update core.branches set time_zone=p_time_zone where id=p_branch;
end $$;

create or replace function public.admin_save_pickup_window(
 p_id uuid,p_branch uuid,p_weekday smallint,p_opens time,p_closes time,
 p_slot_minutes smallint,p_capacity smallint,p_prep_minutes smallint,p_enabled boolean
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid:=coalesce(p_id,gen_random_uuid());
begin
 if not identity.has_permission('settings.write') or not identity.can_manage_branch(p_branch) then raise insufficient_privilege; end if;
 if p_weekday not between 0 and 6 or p_opens>=p_closes or p_slot_minutes not between 5 and 240 or p_capacity not between 1 and 500 or p_prep_minutes not between 0 and 480 then raise exception 'invalid pickup window'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_branch::text||':'||p_weekday::text,0));
 if exists(select 1 from core.branch_pickup_windows w where w.branch_id=p_branch and w.weekday=p_weekday and w.enabled and p_enabled and w.id<>v_id and p_opens<w.closes_at and p_closes>w.opens_at) then raise exception 'pickup windows overlap'; end if;
 insert into core.branch_pickup_windows(id,branch_id,weekday,opens_at,closes_at,slot_minutes,capacity,prep_minutes,enabled)
 values(v_id,p_branch,p_weekday,p_opens,p_closes,p_slot_minutes,p_capacity,p_prep_minutes,p_enabled)
 on conflict(id) do update set opens_at=excluded.opens_at,closes_at=excluded.closes_at,slot_minutes=excluded.slot_minutes,capacity=excluded.capacity,prep_minutes=excluded.prep_minutes,enabled=excluded.enabled
 where core.branch_pickup_windows.branch_id=p_branch;
 if not found then raise exception 'pickup window not found'; end if;
 return v_id;
end $$;

create or replace function public.admin_delete_pickup_window(p_id uuid,p_branch uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not identity.has_permission('settings.write') or not identity.can_manage_branch(p_branch) then raise insufficient_privilege; end if;
 delete from core.branch_pickup_windows where id=p_id and branch_id=p_branch;
end $$;

create or replace function public.admin_save_pickup_exception(
 p_id uuid,p_branch uuid,p_date date,p_closed boolean,p_opens time,p_closes time,
 p_slot_minutes smallint,p_capacity smallint
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid:=coalesce(p_id,gen_random_uuid());
begin
 if not identity.has_permission('settings.write') or not identity.can_manage_branch(p_branch) then raise insufficient_privilege; end if;
 if p_date<current_date or (not p_closed and (p_opens is null or p_closes is null or p_opens>=p_closes)) or (p_slot_minutes is not null and p_slot_minutes not between 5 and 240) or (p_capacity is not null and p_capacity not between 1 and 500) then raise exception 'invalid pickup exception'; end if;
 insert into core.branch_pickup_exceptions(id,branch_id,exception_date,closed,opens_at,closes_at,slot_minutes,capacity)
 values(v_id,p_branch,p_date,p_closed,p_opens,p_closes,p_slot_minutes,p_capacity)
 on conflict(branch_id,exception_date) do update set closed=excluded.closed,opens_at=excluded.opens_at,closes_at=excluded.closes_at,slot_minutes=excluded.slot_minutes,capacity=excluded.capacity returning id into v_id;
 return v_id;
end $$;

create or replace function public.admin_delete_pickup_exception(p_id uuid,p_branch uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not identity.has_permission('settings.write') or not identity.can_manage_branch(p_branch) then raise insufficient_privilege; end if;
 delete from core.branch_pickup_exceptions where id=p_id and branch_id=p_branch;
end $$;

revoke all on function public.admin_pickup_schedule(uuid),public.admin_set_branch_time_zone(uuid,text),public.admin_save_pickup_window(uuid,uuid,smallint,time,time,smallint,smallint,smallint,boolean),public.admin_delete_pickup_window(uuid,uuid),public.admin_save_pickup_exception(uuid,uuid,date,boolean,time,time,smallint,smallint),public.admin_delete_pickup_exception(uuid,uuid) from public,anon;
grant execute on function public.admin_pickup_schedule(uuid),public.admin_set_branch_time_zone(uuid,text),public.admin_save_pickup_window(uuid,uuid,smallint,time,time,smallint,smallint,smallint,boolean),public.admin_delete_pickup_window(uuid,uuid),public.admin_save_pickup_exception(uuid,uuid,date,boolean,time,time,smallint,smallint) to authenticated;

create or replace function public.admin_list_account_deletion_requests(p_limit integer default 100)
returns setof jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not identity.has_permission('admin.staff.write') then raise insufficient_privilege; end if;
 return query select jsonb_build_object('id',r.id,'user_id',r.user_id,'status',r.status,'created_at',r.created_at,'attempt_count',r.attempt_count,'last_error',r.last_error) from identity.account_deletion_requests r where r.status in ('pending','processing') order by r.created_at limit least(greatest(p_limit,1),200);
end $$;

create or replace function public.admin_claim_account_deletion(p_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_user uuid;
begin
 if not identity.has_permission('admin.staff.write') then raise insufficient_privilege; end if;
 update identity.account_deletion_requests set status='processing',attempt_count=attempt_count+1,last_error=null where id=p_id and status in ('pending','processing') returning user_id into v_user;
 if v_user is null then raise exception 'deletion request not found or closed'; end if;
 return v_user;
end $$;

create or replace function public.admin_reject_account_deletion(p_id uuid,p_note text default null)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not identity.has_permission('admin.staff.write') then raise insufficient_privilege; end if;
 update identity.account_deletion_requests set status='rejected',processed_at=now(),resolution_note=left(coalesce(p_note,'Request reviewed by administration'),300) where id=p_id and status in ('pending','processing');
 if not found then raise exception 'deletion request not found or closed'; end if;
end $$;

create or replace function public.service_finish_account_deletion(p_id uuid,p_user uuid,p_error text default null)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.role()<>'service_role' then raise insufficient_privilege; end if;
 if p_error is null then
  update identity.profiles set full_name='Deleted account',email=null,phone=null,avatar_url=null,branch_id=null where id=p_user;
  update identity.account_deletion_requests set status='completed',processed_at=now(),last_error=null,resolution_note='Account access revoked; profile anonymized; financial and order records retained.' where id=p_id and user_id=p_user;
 else
  update identity.account_deletion_requests set status='pending',last_error=left(p_error,500) where id=p_id and user_id=p_user;
 end if;
end $$;
revoke all on function public.admin_list_account_deletion_requests(integer),public.admin_claim_account_deletion(uuid),public.admin_reject_account_deletion(uuid,text),public.service_finish_account_deletion(uuid,uuid,text) from public,anon;
grant execute on function public.admin_list_account_deletion_requests(integer),public.admin_claim_account_deletion(uuid),public.admin_reject_account_deletion(uuid,text) to authenticated;
grant execute on function public.service_finish_account_deletion(uuid,uuid,text) to service_role;

create or replace function public.available_pickup_slots(p_branch uuid,p_date date)
returns table(slot_start timestamptz,remaining integer) language plpgsql stable security definer set search_path='' as $$
declare v_branch core.branches%rowtype; v_tz text; v_local timestamp; v_day smallint; v_exc core.branch_pickup_exceptions%rowtype; v_closed boolean:=false; v_open time; v_close time; v_step integer; v_capacity integer; v_prep integer; v_start timestamp; v_now timestamp;
begin
 select * into v_branch from core.branches where id=p_branch and is_active;
 if not found or p_date < (now() at time zone v_branch.time_zone)::date then return; end if;
 v_tz:=v_branch.time_zone; v_day:=extract(dow from p_date);
 select * into v_exc from core.branch_pickup_exceptions where branch_id=p_branch and exception_date=p_date;
 if found then if v_exc.closed then return; end if; v_open:=v_exc.opens_at;v_close:=v_exc.closes_at;v_step:=coalesce(v_exc.slot_minutes,15);v_capacity:=coalesce(v_exc.capacity,8);v_prep:=coalesce(nullif(v_branch.settings->>'prep_minutes','')::int,15);
 else
  for v_open,v_close,v_step,v_capacity,v_prep in select opens_at,closes_at,slot_minutes,capacity,prep_minutes from core.branch_pickup_windows where branch_id=p_branch and weekday=v_day and enabled loop
   v_local:=p_date+v_open; v_now:=now() at time zone v_tz;
   while v_local+make_interval(mins=>v_prep)<=p_date+v_close loop
    if (v_local at time zone v_tz)>=now()+make_interval(mins=>v_prep) then
      slot_start:=v_local at time zone v_tz;
      select greatest(v_capacity-coalesce(occupied,0),0) into remaining from orders.pickup_slot_capacity where branch_id=p_branch and orders.pickup_slot_capacity.slot_start=slot_start;
      if not found then remaining:=v_capacity; end if;
      if remaining>0 then return next; end if;
    end if;
    v_local:=v_local+make_interval(mins=>v_step);
   end loop;
  end loop; return;
 end if;
 v_local:=p_date+v_open;v_now:=now() at time zone v_tz;
 while v_local+make_interval(mins=>v_prep)<=p_date+v_close loop
  if (v_local at time zone v_tz)>=now()+make_interval(mins=>v_prep) then
   slot_start:=v_local at time zone v_tz;
   select greatest(v_capacity-coalesce(occupied,0),0) into remaining from orders.pickup_slot_capacity where branch_id=p_branch and orders.pickup_slot_capacity.slot_start=slot_start;
   if not found then remaining:=v_capacity;end if;if remaining>0 then return next;end if;
  end if;
  v_local:=v_local+make_interval(mins=>v_step);
 end loop;
end $$;
revoke all on function public.available_pickup_slots(uuid,date) from public,anon;
grant execute on function public.available_pickup_slots(uuid,date) to authenticated;

create or replace function public.available_pickup_days(p_branch uuid,p_start date,p_days integer default 14)
returns table(service_date date) language plpgsql stable security definer set search_path='' as $$
declare v_start date;
begin
 if p_days<1 or p_days>31 then raise exception 'invalid pickup day range'; end if;
 select greatest(p_start,(now() at time zone b.time_zone)::date) into v_start from core.branches b where b.id=p_branch and b.is_active;
 if v_start is null then return; end if;
 return query select day::date from generate_series(v_start,v_start+(p_days-1),interval '1 day') as days(day)
 where exists(select 1 from public.available_pickup_slots(p_branch,day::date));
end $$;
revoke all on function public.available_pickup_days(uuid,date,integer) from public,anon;
grant execute on function public.available_pickup_days(uuid,date,integer) to authenticated;

-- Capacity reservation is serialized by the primary-key row and a conditional
-- update. Adding the scheduled timestamp to an order cannot overbook a slot.
create or replace function orders.reserve_pickup_capacity()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_tz text; v_local timestamp; v_cap integer; v_prep integer; v_step integer; v_open time; v_close time; v_exception core.branch_pickup_exceptions%rowtype; v_count integer;
begin
 if tg_op='UPDATE' then
  if old.scheduled_pickup_at is not distinct from new.scheduled_pickup_at then return new; end if;
  if old.scheduled_pickup_at is not null then raise exception 'pickup schedule cannot be changed after order creation'; end if;
 end if;
 if new.fulfillment_type<>'pickup' or new.scheduled_pickup_at is null then return new; end if;
 select time_zone into v_tz from core.branches where id=new.branch_id and is_active;
 if v_tz is null then raise exception 'branch unavailable'; end if;
 v_local:=new.scheduled_pickup_at at time zone v_tz;
 if new.scheduled_pickup_at<=now() then raise exception 'pickup slot is in the past'; end if;
 select * into v_exception from core.branch_pickup_exceptions where branch_id=new.branch_id and exception_date=v_local::date;
 if found then
  v_open:=v_exception.opens_at; v_close:=v_exception.closes_at; v_step:=coalesce(v_exception.slot_minutes,15); v_prep:=coalesce((select nullif(settings->>'prep_minutes','')::int from core.branches where id=new.branch_id),15);
  v_cap:=coalesce(v_exception.capacity,8);
 else
  select capacity,slot_minutes,prep_minutes,opens_at,closes_at into v_cap,v_step,v_prep,v_open,v_close from core.branch_pickup_windows where branch_id=new.branch_id and weekday=extract(dow from v_local)::int and enabled and v_local::time>=opens_at and v_local::time<closes_at order by opens_at limit 1;
 end if;
 if v_exception.closed or v_cap is null or v_local::time<v_open or v_local::time>=v_close or v_local::time+make_interval(mins=>v_prep)>v_close or mod(extract(epoch from (v_local::time-v_open))::int,v_step)<>0 then raise exception 'invalid pickup slot'; end if;
 if not exists(select 1 from public.available_pickup_slots(new.branch_id,v_local::date) s where s.slot_start=new.scheduled_pickup_at) then raise exception 'pickup slot unavailable'; end if;
 insert into orders.pickup_slot_capacity(branch_id,slot_start,occupied) values(new.branch_id,new.scheduled_pickup_at,1)
 on conflict(branch_id,slot_start) do update set occupied=orders.pickup_slot_capacity.occupied+1
 where orders.pickup_slot_capacity.occupied<v_cap returning occupied into v_count;
 if v_count is null then raise exception 'pickup slot full'; end if;
 return new;
end $$;
drop trigger if exists reserve_pickup_capacity on orders.orders;
create trigger reserve_pickup_capacity before insert or update of scheduled_pickup_at on orders.orders for each row execute function orders.reserve_pickup_capacity();

create or replace function orders.release_pickup_capacity()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.scheduled_pickup_at is not null and new.status='cancelled' and old.status<>'cancelled' then
  update orders.pickup_slot_capacity set occupied=greatest(occupied-1,0) where branch_id=old.branch_id and slot_start=old.scheduled_pickup_at;
 end if; return new;
end $$;
drop trigger if exists release_pickup_capacity on orders.orders;
create trigger release_pickup_capacity after update of status on orders.orders for each row execute function orders.release_pickup_capacity();

create or replace function public.admin_order_pickup_schedules()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not identity.is_staff() or not identity.has_permission('orders.read') then raise insufficient_privilege; end if;
 return coalesce((select jsonb_object_agg(id::text,scheduled_pickup_at) from orders.orders where scheduled_pickup_at is not null and identity.can_manage_branch(branch_id)),'{}'::jsonb);
end $$;
revoke all on function public.admin_order_pickup_schedules() from public,anon;
grant execute on function public.admin_order_pickup_schedules() to authenticated;

create or replace function public.place_order_with_pickup_schedule(
 p_branch_id uuid,p_lines jsonb,p_idempotency_key text,p_expected_total numeric,
 p_delivery_zone_id uuid default null,p_coupon_code text default null,p_note text default null,
 p_address_id uuid default null,p_scheduled_pickup_at timestamptz default null,
 p_subscription_run_id uuid default null
) returns table(order_id uuid,order_number text,subtotal numeric,discount_total numeric,delivery_fee numeric,tax_total numeric,grand_total numeric,points_earned integer,reused_existing_order boolean,product_discount_total numeric)
language plpgsql security invoker set search_path='' as $$
declare v_order record; v_saved orders.orders%rowtype;
begin
 select * into v_order from public.place_order_with_quote(p_branch_id,p_lines,p_idempotency_key,'pickup',p_expected_total,null,p_coupon_code,p_note,p_address_id,p_subscription_run_id);
 if p_scheduled_pickup_at is not null then
  update orders.orders set scheduled_pickup_at=p_scheduled_pickup_at where id=v_order.order_id and branch_id=p_branch_id and user_id=auth.uid() and fulfillment_type='pickup';
 end if;
 select * into v_saved from orders.orders where id=v_order.order_id;
 return query select v_saved.id,v_saved.order_number,v_saved.subtotal,v_saved.discount_total,v_saved.delivery_fee,v_saved.tax_total,v_saved.grand_total,v_saved.loyalty_points_earned,v_order.reused_existing_order,coalesce(v_saved.product_discount_total,0);
end $$;
revoke all on function public.place_order_with_pickup_schedule(uuid,jsonb,text,numeric,uuid,text,text,uuid,timestamptz,uuid) from public,anon;
grant execute on function public.place_order_with_pickup_schedule(uuid,jsonb,text,numeric,uuid,text,text,uuid,timestamptz,uuid) to authenticated;
