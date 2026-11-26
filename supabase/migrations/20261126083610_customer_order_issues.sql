create table orders.customer_issues (
 id uuid primary key default gen_random_uuid(),
 order_id uuid not null references orders.orders(id),
 item_id uuid references orders.order_items(id) on delete set null,
 reason text not null check(reason in ('missing','incorrect','delay','other')),
 message text not null check(length(message)<=1000),
 photo text check(length(photo)<=400000 and photo ~ '^[A-Za-z0-9+/]+=*$'),
 created_at timestamptz not null default now(),
 reply text check(length(trim(reply)) between 1 and 1000),
 replied_at timestamptz
);
alter table orders.customer_issues enable row level security;
revoke all on orders.customer_issues from public, anon, authenticated;
create unique index customer_issues_one_open on orders.customer_issues(order_id) where reply is null;
create index customer_issues_order on orders.customer_issues(order_id,created_at desc);

create function public.customer_order_issues(p_order uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(to_jsonb(i) order by i.created_at desc),'[]'::jsonb)
 from orders.customer_issues i join orders.orders o on o.id=i.order_id
 where o.id=p_order and (o.user_id=auth.uid() or (identity.is_staff() and identity.has_permission('orders.read') and identity.can_manage_branch(o.branch_id)))
$$;
create function public.report_order_issue(p_order uuid,p_item uuid,p_reason text,p_message text,p_photo text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select from orders.orders where id=p_order and user_id=auth.uid()) then raise insufficient_privilege; end if;
 if p_item is not null and not exists(select from orders.order_items where id=p_item and order_id=p_order) then raise exception 'invalid item'; end if;
 insert into orders.customer_issues(order_id,item_id,reason,message,photo) values(p_order,p_item,p_reason,trim(p_message),p_photo);
end $$;
create function public.reply_order_issue(p_issue uuid,p_reply text) returns void language plpgsql security definer set search_path='' as $$
begin
 if p_reply is null or not identity.is_staff() or not identity.has_permission('orders.status.update') then raise insufficient_privilege; end if;
 update orders.customer_issues i set reply=trim(p_reply), replied_at=now() from orders.orders o where i.id=p_issue and i.order_id=o.id and i.reply is null and identity.can_manage_branch(o.branch_id);
 if not found then raise exception 'issue unavailable'; end if;
end $$;
revoke all on function public.customer_order_issues(uuid), public.report_order_issue(uuid,uuid,text,text,text), public.reply_order_issue(uuid,text) from public, anon;
grant execute on function public.customer_order_issues(uuid), public.report_order_issue(uuid,uuid,text,text,text), public.reply_order_issue(uuid,text) to authenticated;
