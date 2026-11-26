select p.id, p.full_name,
 (select count(*) from identity.customer_addresses a where a.user_id=p.id and a.archived_at is null) as addresses,
 (select count(*) from orders.orders o where o.user_id=p.id) as orders,
 (select count(*) from subscriptions.subscriptions s where s.user_id=p.id) as subscriptions
from identity.profiles p
where not exists (select 1 from identity.staff_members sm where sm.user_id=p.id)
order by orders desc, subscriptions desc, addresses desc
limit 10;