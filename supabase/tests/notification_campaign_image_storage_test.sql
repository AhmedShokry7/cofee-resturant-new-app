-- Image access for notification campaigns must be independent of catalogue writes.
\set ON_ERROR_STOP on

select case when exists (
  select 1 from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and policyname = 'notification_campaign_images_insert'
     and cmd = 'INSERT'
     and with_check ilike '%notifications.send%'
     and with_check ilike '%notifications%'
) then 'PASS' else 'FAIL: campaign image insert policy is missing or unscoped' end as insert_policy;

select case when exists (
  select 1 from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and policyname = 'notification_campaign_images_update'
     and cmd = 'UPDATE'
     and qual ilike '%notifications.send%'
     and with_check ilike '%notifications.send%'
) then 'PASS' else 'FAIL: campaign image update policy is missing or unscoped' end as update_policy;

select case when exists (
  select 1 from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and policyname = 'notification_campaign_images_delete'
     and cmd = 'DELETE'
     and qual ilike '%notifications.send%'
) then 'PASS' else 'FAIL: campaign image delete policy is missing or unscoped' end as delete_policy;

select case when exists (
  select 1 from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and policyname = 'product_images_staff_insert'
     and with_check ilike '%catalog.product.write%'
     and with_check ilike '%notifications%'
) then 'PASS' else 'FAIL: product insert policy no longer excludes notifications' end as product_policy_is_separate;
