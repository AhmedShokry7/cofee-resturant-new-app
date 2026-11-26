select table_schema, table_name, column_name, data_type, is_nullable, column_default
from information_schema.columns
where (table_schema='identity' and table_name='customer_addresses')
   or (table_schema='subscriptions' and table_name in ('plans','subscriptions'))
order by table_schema, table_name, ordinal_position;