begin;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"d133415e-3457-4bb8-b357-3f09cf741f1a","role":"authenticated","aud":"authenticated"}',true);
select md5(public.admin_customer_details('534c5b4d-cd2a-4234-b0a0-404000bf0ff4')::text) as fingerprint,
       length(public.admin_customer_details('534c5b4d-cd2a-4234-b0a0-404000bf0ff4')::text) as bytes,
       jsonb_array_length(public.admin_customer_details('534c5b4d-cd2a-4234-b0a0-404000bf0ff4') -> 'orders') as orders,
       jsonb_array_length(public.admin_customer_details('534c5b4d-cd2a-4234-b0a0-404000bf0ff4') -> 'addresses') as addresses,
       jsonb_array_length(public.admin_customer_details('534c5b4d-cd2a-4234-b0a0-404000bf0ff4') -> 'subscriptions') as subscriptions;
rollback;