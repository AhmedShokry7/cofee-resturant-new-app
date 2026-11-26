param([string]$File)
$text = Get-Content -Path $File -Raw -Encoding UTF8
$marker = 'create or replace function public.admin_dashboard_metrics()'
$start = $text.IndexOf($marker)
if ($start -lt 0) { Write-Error "marker not found"; exit 1 }
$bodyStart = $text.IndexOf('$fn$', $start) + 4
$bodyEnd = $text.IndexOf('$fn$', $bodyStart)
$body = $text.Substring($bodyStart, $bodyEnd - $bodyStart)
Write-Host ("len_chars=" + $body.Length)
$t = $body.IndexOf('test_only')
Write-Host ("test_only_pos=" + $t)
$tp = $body.IndexOf('top_products as (')
Write-Host ("top_products_pos=" + $tp)
$pid = $body.IndexOf('product_id')
Write-Host ("product_id_pos=" + $pid)
$mb = $body.IndexOf('mb')
Write-Host ("month_baseline_pos=" + $mb)
