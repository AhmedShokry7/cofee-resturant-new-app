param([Parameter(Mandatory=$true)][string]$SqlFile, [switch]$ReadOnly)
$ErrorActionPreference = 'Stop'
$cfg = @{}
Get-Content (Join-Path $PSScriptRoot '../../.env') | ForEach-Object {
  if ($_ -match '^([A-Z_]+)=(.*)$') {
    $cfg[$matches[1]] = $matches[2].Trim().Trim('"').Trim("'")
  }
}
$ref = ([uri]$cfg.SUPABASE_URL).Host.Split('.')[0]
$body = @{query=(Get-Content -LiteralPath $SqlFile -Raw);read_only=[bool]$ReadOnly} | ConvertTo-Json
$result = Invoke-RestMethod -Uri "https://api.supabase.com/v1/projects/$ref/database/query" -Method Post -Headers @{Authorization="Bearer $($cfg.SUPABASE_ACCESS_TOKEN)"} -ContentType 'application/json' -Body $body -TimeoutSec 60
$result | ConvertTo-Json -Depth 20
