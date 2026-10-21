# Checks that the in-app assistant can actually answer.
#
# Use it after rotating a provider key: the health endpoint only says which
# providers are *configured*, not which one answers. This asks a real question
# and reports who replied.
#
#   .\tools\check_ai_assistant.ps1
param(
  [string]$ProjectRef = 'webzzasosevzymftgszn'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $projectRoot '.env'
if (-not (Test-Path -LiteralPath $envFile)) { throw "Missing $envFile" }

$supabaseUrl = (Select-String -Path $envFile -Pattern '^SUPABASE_URL=(.+)$').Matches[0].Groups[1].Value.Trim()
$publishable = (Select-String -Path $envFile -Pattern '^SUPABASE_PUBLISHABLE_KEY=(.+)$').Matches[0].Groups[1].Value.Trim()

Write-Host ''
Write-Host 'Configured providers ...'
try {
  $health = Invoke-RestMethod -Uri "$supabaseUrl/functions/v1/ai-assistant" -Method Get `
    -Headers @{ apikey = $publishable } -TimeoutSec 30
  if (-not $health.ok) {
    Write-Host '  none — the secrets are missing. Run: .\tools\setup_ai_assistant.ps1'
    exit 1
  }
  foreach ($provider in $health.providers) {
    Write-Host "  $($provider.name): $($provider.model)"
  }
}
catch {
  Write-Host "  the health check did not answer: $($_.Exception.Message)"
  exit 1
}

Write-Host ''
Write-Host 'Asking a real question ...'
$question = 'ايه احلى مشروب عندكم؟'
$body = @{
  messages = @(
    @{ role = 'system'; content = 'You are a coffee shop assistant. Answer in Egyptian Arabic. Prices are in SAR with Latin digits.' }
    @{ role = 'user'; content = $question }
  )
} | ConvertTo-Json -Depth 5

# The file is written as UTF-8 so the Arabic reaches the function intact.
$tmp = Join-Path $env:TEMP 'ai_check_body.json'
[System.IO.File]::WriteAllText($tmp, $body, (New-Object System.Text.UTF8Encoding $false))

try {
  $stopwatch = [Diagnostics.Stopwatch]::StartNew()
  $reply = Invoke-RestMethod -Uri "$supabaseUrl/functions/v1/ai-assistant" -Method Post `
    -Headers @{ apikey = $publishable; 'Content-Type' = 'application/json' } `
    -Body ([System.IO.File]::ReadAllBytes($tmp)) -TimeoutSec 60
  $stopwatch.Stop()
  Write-Host "  answered by: $($reply.provider) ($($stopwatch.ElapsedMilliseconds)ms)"
  Write-Host "  $($reply.text)"
  Write-Host ''
  Write-Host 'RESULT: OK'
  exit 0
}
catch {
  Write-Host ''
  Write-Host "RESULT: FAILED — $($_.Exception.Message)"
  if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
    Write-Host "  $($_.ErrorDetails.Message)"
  }
  Write-Host ''
  Write-Host 'If every provider is refused, the key stored in Supabase is not the'
  Write-Host 'one you created. Write the new key into .env.llm and run:'
  Write-Host '  .\tools\setup_ai_assistant.ps1'
  exit 1
}
finally {
  Remove-Item $tmp -Force -ErrorAction SilentlyContinue
}
