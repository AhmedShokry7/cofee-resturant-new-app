select 'dashboard', jsonb_typeof(public.admin_dashboard_metrics()->'top_products') as top_type,
       public.admin_dashboard_metrics()->'top_products'->0 as sample
;
