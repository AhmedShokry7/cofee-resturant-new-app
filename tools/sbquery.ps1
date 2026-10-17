# UTF-8-clean query helper for the Supabase Management API.
# Usage:
#   . sbquery.ps1
#   Invoke-SbQuery -Sql "select 1"
#   Invoke-SbQuery -SqlFile path.sql
# Returns the raw response text (UTF-8 decoded), or "ERR: ..." .
param()

Add-Type -AssemblyName System.Net.Http

$script:SbToken = $null
$script:SbUri = 'https://api.supabase.com/v1/projects/webzzasosevzymftgszn/database/query'

function Get-SbToken {
  if (-not $script:SbToken) {
    $script:SbToken = (Select-String -Path 'D:\new_cofee\.env' -Pattern '^SUPABASE_ACCESS_TOKEN=(.+)$').Matches[0].Groups[1].Value
  }
  return $script:SbToken
}

function Invoke-SbQuery {
  param(
    [string]$Sql,
    [string]$SqlFile
  )
  if ($SqlFile) { $Sql = Get-Content -Path $SqlFile -Raw -Encoding UTF8 }

  $json = @{ query = $Sql } | ConvertTo-Json -Depth 12 -Compress
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)

  $handler = New-Object System.Net.Http.HttpClientHandler
  $client = New-Object System.Net.Http.HttpClient($handler)
  $client.Timeout = [TimeSpan]::FromSeconds(300)
  $client.DefaultRequestHeaders.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue('Bearer', (Get-SbToken))

  $content = [System.Net.Http.ByteArrayContent]::new($bytes)
  $content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::new('application/json')
  $content.Headers.ContentType.CharSet = 'utf-8'

  try {
    $resp = $client.PostAsync($script:SbUri, $content).Result
    $respBytes = $resp.Content.ReadAsByteArrayAsync().Result
    $text = [System.Text.Encoding]::UTF8.GetString($respBytes)
    if (-not $resp.IsSuccessStatusCode) {
      return "ERR: HTTP $([int]$resp.StatusCode) :: $text"
    }
    return $text
  } catch {
    return "ERR: $($_.Exception.Message)"
  } finally {
    $client.Dispose()
  }
}

# Convenience: run a query and emit rows as TSV (first row = column names)
function Invoke-SbQueryTsv {
  param([string]$Sql, [string]$SqlFile)
  $raw = Invoke-SbQuery -Sql $Sql -SqlFile $SqlFile
  if ($raw -like 'ERR:*') { return $raw }
  $parsed = $raw | ConvertFrom-Json
  $rows = @()
  if ($parsed -is [System.Array]) { foreach ($p in $parsed) { $rows += $p } }
  elseif ($null -ne $parsed) { $rows += $parsed }
  if ($rows.Count -eq 0) { return '' }
  $cols = $rows[0].PSObject.Properties.Name
  Write-Output ($cols -join "`t")
  foreach ($r in $rows) {
    $vals = foreach ($c in $cols) { "$($r.$c)" }
    Write-Output ($vals -join "`t")
  }
}
