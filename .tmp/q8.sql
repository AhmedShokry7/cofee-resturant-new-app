select substring(pg_get_functiondef('public.admin_dashboard_metrics()'::regprocedure) from 'top_products as \(.*?recent_orders as \(') as top_snippet;
