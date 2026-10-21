param(
  # One key per provider. Every provider given is switched on; the function
  # then tries them in order (Groq, OpenRouter, Gemini) and falls over to the
  # next one when the first is rate-limited.
  [string]$Groq = '',
  [string]$OpenRouter = '',
  [string]$Gemini = '',

  # Any other OpenAI-compatible endpoint.
  [string]$ApiKey = '',
  [string]$BaseUrl = '',
  [string]$Model = '',

  # Overrides for the models of the built-in providers.
  [string]$GroqModel = '',
  [string]$OpenRouterModel = '',
  [string]$GeminiModel = '',

  [string]$ProjectRef = 'webzzasosevzymftgszn',

  # Only write the secrets and stop.
  [switch]$SkipTest
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

# ---------------------------------------------------------------------------
# Keys can live in a local file so they are typed once.
#
# `.env.llm` holds one line per key:
#
#   GROQ_API_KEY=gsk_...
#   OPENROUTER_API_KEY=sk-or-...
#   GEMINI_API_KEY=AIza...
#
# The file is ignored by git, so the keys stay on the machine. A parameter
# given on the command line always wins over the file.
# ---------------------------------------------------------------------------
$keyFile = Join-Path $projectRoot '.env.llm'
if (Test-Path -LiteralPath $keyFile) {
  $fileValues = @{}
  foreach ($line in Get-Content -LiteralPath $keyFile -Encoding UTF8) {
    if ($line -notmatch '^\s*([A-Z_]+)\s*=\s*(.+?)\s*$') { continue }
    $fileValues[$matches[1]] = $matches[2].Trim().Trim('"').Trim("'")
  }
  if (-not $Groq -and $fileValues.ContainsKey('GROQ_API_KEY')) {
    $Groq = $fileValues['GROQ_API_KEY']
  }
  if (-not $OpenRouter -and $fileValues.ContainsKey('OPENROUTER_API_KEY')) {
    $OpenRouter = $fileValues['OPENROUTER_API_KEY']
  }
  if (-not $Gemini -and $fileValues.ContainsKey('GEMINI_API_KEY')) {
    $Gemini = $fileValues['GEMINI_API_KEY']
  }
  if (-not $GroqModel -and $fileValues.ContainsKey('GROQ_MODEL')) {
    $GroqModel = $fileValues['GROQ_MODEL']
  }
  if (-not $OpenRouterModel -and $fileValues.ContainsKey('OPENROUTER_MODEL')) {
    $OpenRouterModel = $fileValues['OPENROUTER_MODEL']
  }
  if (-not $GeminiModel -and $fileValues.ContainsKey('GEMINI_MODEL')) {
    $GeminiModel = $fileValues['GEMINI_MODEL']
  }
}

# ---------------------------------------------------------------------------
# The providers, in one place. Each one is free to start with and speaks the
# OpenAI protocol, which is what the edge function expects.
# ---------------------------------------------------------------------------
$providers = @(
  @{
    name = 'groq'
    key = $Groq
    secret = 'GROQ_API_KEY'
    modelSecret = 'GROQ_MODEL'
    model = if ($GroqModel) { $GroqModel } else { 'openai/gpt-oss-120b' }
    signup = 'https://console.groq.com/keys'
    note = 'Groq free plan: 30 requests a minute, 1000 a day, open weights (gpt-oss / Qwen).'
  }
  @{
    name = 'openrouter'
    key = $OpenRouter
    secret = 'OPENROUTER_API_KEY'
    modelSecret = 'OPENROUTER_MODEL'
    model = if ($OpenRouterModel) { $OpenRouterModel } else { 'openrouter/free' }
    signup = 'https://openrouter.ai/keys'
    note = 'OpenRouter free models: about 200 requests a day, many open models behind one key.'
  }
  @{
    name = 'gemini'
    key = $Gemini
    secret = 'GEMINI_API_KEY'
    modelSecret = 'GEMINI_MODEL'
    model = if ($GeminiModel) { $GeminiModel } else { 'gemini-3.8-flash' }
    signup = 'https://aistudio.google.com/apikey'
    note = 'Google AI Studio free tier: Gemini Flash and the open Gemma models.'
  }
)

$chosen = @($providers | Where-Object { $_.key })

if ($ApiKey) {
  if (-not $BaseUrl -or -not $Model) {
    Write-Host 'A generic provider needs -BaseUrl and -Model as well.'
    exit 1
  }
  $chosen += @{
    name = 'generic'
    key = $ApiKey
    secret = 'LLM_API_KEY'
    modelSecret = 'LLM_MODEL'
    model = $Model
    signup = ''
    note = ''
    baseUrl = $BaseUrl
  }
}

if ($chosen.Count -eq 0) {
  Write-Host 'No provider key given. Free keys to get:'
  foreach ($provider in $providers) {
    Write-Host ''
    Write-Host "  $($provider.name):"
    Write-Host "    key from : $($provider.signup)"
    Write-Host "    limit   : $($provider.note)"
  }
  Write-Host ''
  Write-Host 'Put the keys in .env.llm (one line each) or pass them on the command line:'
  Write-Host '  GROQ_API_KEY=gsk_...'
  Write-Host '  OPENROUTER_API_KEY=sk-or-...'
  Write-Host '  GEMINI_API_KEY=AIza...'
  Write-Host ''
  Write-Host 'Then run:'
  Write-Host '  .\tools\setup_ai_assistant.ps1'
  exit 1
}

# The access token that owns the project.
$envFile = Join-Path $projectRoot '.env'
if (-not (Test-Path -LiteralPath $envFile)) { throw "Missing $envFile" }
$accessToken = (Select-String -Path $envFile -Pattern '^SUPABASE_ACCESS_TOKEN=(.+)$').Matches[0].Groups[1].Value.Trim()
if (-not $accessToken) { throw 'SUPABASE_ACCESS_TOKEN is missing from .env' }
$env:SUPABASE_ACCESS_TOKEN = $accessToken

Write-Host 'Writing the secrets ...'
$secretArgs = @('secrets', 'set')
foreach ($provider in $chosen) {
  $secretArgs += "$($provider.secret)=$($provider.key)"
  if ($provider.model) { $secretArgs += "$($provider.modelSecret)=$($provider.model)" }
  if ($provider.baseUrl) { $secretArgs += "LLM_BASE_URL=$($provider.baseUrl)" }
}
& supabase @secretArgs --project-ref $ProjectRef
if ($LASTEXITCODE -ne 0) { throw 'The secrets could not be written.' }
Write-Host "  enabled: $($chosen.name -join ', ')"

# The function reports which providers it can reach, without their keys.
$envFile = Join-Path $projectRoot '.env'
$supabaseUrl = (Select-String -Path $envFile -Pattern '^SUPABASE_URL=(.+)$').Matches[0].Groups[1].Value.Trim()
$publishable = (Select-String -Path $envFile -Pattern '^SUPABASE_PUBLISHABLE_KEY=(.+)$').Matches[0].Groups[1].Value.Trim()
try {
  $health = Invoke-RestMethod -Uri "$supabaseUrl/functions/v1/ai-assistant" -Method Get `
    -Headers @{ apikey = $publishable } -TimeoutSec 30
  Write-Host "  live   : $($health.providers.name -join ', ')"
}
catch {
  Write-Host '  live   : the health check did not answer yet; the function may still be deploying.'
}

if ($SkipTest) { exit 0 }

# ---------------------------------------------------------------------------
# Test: a call must come back with an answer from one of the providers.
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host 'Testing the assistant ...'

$probeEmail = "ai.check.$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())@example.com"
$probePassword = 'AiCheck-Probe-123!'
$signup = @{
  email = $probeEmail
  password = $probePassword
} | ConvertTo-Json
$session = Invoke-RestMethod -Uri "$supabaseUrl/auth/v1/signup" -Method Post `
  -Headers @{ apikey = $publishable; 'Content-Type' = 'application/json' } -Body $signup

try {
  $headers = @{
    apikey = $publishable
    Authorization = "Bearer $($session.access_token)"
    'Content-Type' = 'application/json'
  }
  $body = @{
    messages = @(
      @{ role = 'system'; content = 'You are a helpful assistant for a coffee shop.' }
      @{ role = 'user'; content = 'Reply with the single word: ready' }
    )
  } | ConvertTo-Json -Depth 5

  $reply = Invoke-RestMethod -Uri "$supabaseUrl/functions/v1/ai-assistant" -Method Post `
    -Headers $headers -Body $body -TimeoutSec 60

  Write-Host ''
  Write-Host "RESULT: OK - the assistant answered through $($reply.provider):"
  Write-Host "  $($reply.text)"
  exit 0
}
catch {
  $detail = ''
  if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
    $detail = $_.ErrorDetails.Message
  }
  elseif ($_.Exception.Response) {
    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
    $detail = $reader.ReadToEnd()
  }
  else {
    $detail = $_.Exception.Message
  }
  Write-Host ''
  Write-Host "RESULT: FAILED - the function did not answer. $detail"
  exit 1
}
finally {
  # The probe account is only a test account; it leaves no trace behind.
  $serviceRole = (Select-String -Path $envFile -Pattern '^SUPABASE_SERVICE_ROLE_KEY=(.+)$').Matches[0].Groups[1].Value.Trim()
  Invoke-RestMethod -Uri "$supabaseUrl/auth/v1/admin/users/$($session.user.id)" -Method Delete `
    -Headers @{ apikey = $serviceRole; Authorization = "Bearer $serviceRole" } | Out-Null
}
