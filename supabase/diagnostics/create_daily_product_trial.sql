begin;
do $$
declare v_user uuid := '534c5b4d-cd2a-4234-b0a0-404000bf0ff4'; v_branch uuid := '9e438aaf-ddde-4b7c-8331-d5a0627ab50c'; v_product uuid := '26da723c-2075-4b07-9651-6d9d73f17512'; v_id uuid; v_due timestamptz := now() - interval '1 minute';
begin
 if not exists (select 1 from auth.users where id=v_user) then raise exception 'target customer missing'; end if;
 if not exists (select 1 from core.branches where id=v_branch and is_active) then raise exception 'branch unavailable'; end if;
 if not exists (select 1 from catalog.products where id=v_product and is_active) then raise exception 'product unavailable'; end if;
 select id into v_id from subscriptions.customer_product_subscriptions where user_id=v_user and name='تجربة أمريكانو يوميًا' and status='active' limit 1;
 if v_id is null then
  v_id := gen_random_uuid();
  insert into subscriptions.customer_product_subscriptions(id,user_id,name,status,recurrence_type,interval_value,start_date,next_run_at,branch_id,fulfillment_type,notes)
  values(v_id,v_user,'تجربة أمريكانو يوميًا','active','daily',1,current_date,v_due,v_branch,'pickup','تجربة بطلب يحتاج تأكيد العميل قبل التحضير والدفع');
  insert into subscriptions.customer_product_subscription_items(subscription_id,product_id,quantity,selected_options)
  values(v_id,v_product,1,'{}'::jsonb);
  insert into subscriptions.customer_product_subscription_runs(subscription_id,user_id,scheduled_for,status,idempotency_key)
  values(v_id,v_user,v_due,'pending','daily-trial:'||v_id::text);
 end if;
end $$;
commit;
select s.id,s.name,s.recurrence_type,s.interval_value,s.status,s.next_run_at,(select count(*) from subscriptions.customer_product_subscription_runs r where r.subscription_id=s.id and r.status='pending') as pending_runs from subscriptions.customer_product_subscriptions s where s.user_id='534c5b4d-cd2a-4234-b0a0-404000bf0ff4' and s.name='تجربة أمريكانو يوميًا';
