# What the assistant learned, and what it still does not know.
#
# Every question the local engine could not answer is asked to the language
# model, and the answer is remembered. This lists what was remembered, so the
# shop can see which questions keep coming and turn the good ones into
# permanent knowledge.
#
#   .\tools\assistant_memory.ps1                 # the twenty most used
#   .\tools\assistant_memory.ps1 -Limit 50
#   .\tools\assistant_memory.ps1 -OnlyUnanswered  # what to work on next
param(
  [int]$Limit = 20,
  # Only the questions that are asked most: the ones worth writing down.
  [switch]$OnlyUnanswered,
  [string]$ProjectRef = 'webzzasosevzymftgszn'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $projectRoot '.env'
if (-not (Test-Path -LiteralPath $envFile)) { throw "Missing $envFile" }
$env:SUPABASE_ACCESS_TOKEN = (Select-String -Path $envFile -Pattern '^SUPABASE_ACCESS_TOKEN=(.+)$').Matches[0].Groups[1].Value.Trim()
$env:HOME = Join-Path $env:TEMP 'opencode'

. (Join-Path $PSScriptRoot 'sbquery.ps1')

$order = if ($OnlyUnanswered) { 'hits asc, created_at desc' } else { 'hits desc, created_at desc' }
$sql = @"
select
  hits,
  pinned,
  provider,
  question_key,
  left(question_text, 120) as asked,
  left(answer, 160) as answer
from ai.learned_answers
order by $order
limit $Limit;
"@

$res = Invoke-SbQuery -Sql $sql
if ($res -like 'ERR:*') { Write-Host $res; exit 1 }

$rows = $res | ConvertFrom-Json
if (-not $rows -or @($rows).Count -eq 0) {
  Write-Host 'Nothing learned yet. The first question the local engine cannot'
  Write-Host 'answer is asked to the model, and the answer is kept here.'
  exit 0
}

Write-Host ''
Write-Host "Learned answers ($(@($rows).Count) of the most asked):"
foreach ($row in $rows) {
  $pin = if ($row.pinned) { ' [pinned]' } else { '' }
  Write-Host ''
  Write-Host "  asked $($row.hits) time(s) via $($row.provider)$pin"
  Write-Host "    Q: $($row.asked)"
  Write-Host "    A: $($row.answer)"
}
Write-Host ''
Write-Host 'A question that is asked again and again is worth putting in the'
Write-Host 'local knowledge instead of asking the model every time.'
Write-Host ''
