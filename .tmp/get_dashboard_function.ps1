. ./tools/sbquery.ps1
$json = Invoke-SbQuery -Sql "select pg_get_functiondef('public.admin_dashboard_metrics()'::regprocedure) as function_sql"
if ($json -like 'ERR:*') { throw $json }
$rows = $json | ConvertFrom-Json
$sql = [string]$rows[0].function_sql
if (-not $sql.StartsWith('CREATE OR REPLACE FUNCTION public.admin_dashboard_metrics()')) { throw 'Unexpected function definition' }
$old = @'
      select coalesce(jsonb_agg(jsonb_build_object(
        'product_name_ar', p.product_name_ar,
        'product_name_en', p.product_name_en,
        'image_url', p.image_url,
        'quantity', p.quantity,
        'revenue', p.revenue
      ) order by p.quantity desc, p.revenue desc), '[]'::jsonb) as items
      from (
        select
          oi.product_name_ar,
          oi.product_name_en,
'@
$new = @'
      select coalesce(jsonb_agg(jsonb_build_object(
        'product_id', p.product_id,
        'product_name_ar', p.product_name_ar,
        'product_name_en', p.product_name_en,
        'image_url', p.image_url,
        'quantity', p.quantity,
        'revenue', p.revenue
      ) order by p.quantity desc, p.revenue desc), '[]'::jsonb) as items
      from (
        select
          (array_agg(oi.product_id order by oi.created_at desc)
            filter (where oi.product_id is not null))[1] as product_id,
          oi.product_name_ar,
          oi.product_name_en,
'@
if (-not $sql.Contains($old)) { throw 'Expected top_products block not found in live procedure' }
$sql = $sql.Replace($old, $new)
if (-not $sql.Contains("'product_id', p.product_id")) { throw 'Patch was not applied' }
$path = Join-Path (Get-Location) 'supabase/migrations/20261126080000_admin_dashboard_product_navigation.sql'
[System.IO.File]::WriteAllText($path, $sql + "`n", [System.Text.UTF8Encoding]::new($false))
Write-Output "Created $path with $($sql.Length) characters"
