-- P0.5 LOCAL TEST ONLY. Run in isolated non-production DB, never remote.
-- Tests: notification ACL after p05_notification_acl_hardening.PROPOSED.sql

\set ON_ERROR_STOP on

select case when not has_table_privilege('authenticated','engagement.notifications','UPDATE')
  then 'PASS base table-wide update revoked'
  else 'FAIL base table-wide update still granted' end as base_table_update;

select case when not has_table_privilege('authenticated','public.notifications','UPDATE')
  then 'PASS view table-wide update revoked'
  else 'FAIL view table-wide update still granted' end as view_table_update;

select case when not has_column_privilege('authenticated','engagement.notifications','title_ar','UPDATE')
  then 'PASS base title_ar update revoked'
  else 'FAIL base title_ar update still granted' end as base_title_update;

select case when has_column_privilege('authenticated','engagement.notifications','is_read','UPDATE')
  and has_column_privilege('authenticated','engagement.notifications','read_at','UPDATE')
  then 'PASS base read columns allowed'
  else 'FAIL base read columns missing' end as base_read_columns;

select case when has_column_privilege('authenticated','public.notifications','is_read','UPDATE')
  and has_column_privilege('authenticated','public.notifications','read_at','UPDATE')
  then 'PASS view read columns allowed'
  else 'FAIL view read columns missing' end as view_read_columns;

select case when not has_table_privilege('authenticated','public.notifications','INSERT')
  then 'PASS view insert revoked'
  else 'FAIL view insert still granted' end as view_insert;

select case when not has_table_privilege('authenticated','public.notifications','DELETE')
  then 'PASS view delete revoked'
  else 'FAIL view delete still granted' end as view_delete;

select case when has_function_privilege('authenticated','public.mark_notifications_read(uuid[])','EXECUTE')
  then 'PASS public mark execute present'
  else 'FAIL public mark execute missing' end as mark_execute;

select case when has_function_privilege('authenticated','public.delete_notifications(uuid[])','EXECUTE')
  then 'PASS public delete execute present'
  else 'FAIL public delete execute missing' end as delete_execute;
