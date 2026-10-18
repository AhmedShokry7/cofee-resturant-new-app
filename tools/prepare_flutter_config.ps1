param(
  [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$envPath = Join-Path $ProjectRoot '.env'
$configPath = Join-Path $ProjectRoot '.env.flutter.json'

if (-not (Test-Path -LiteralPath $envPath -PathType Leaf)) {
  throw "Missing $envPath. Create it from .env.example and fill in the Supabase URL and publishable key."
}

$values = @{}
foreach ($line in Get-Content -LiteralPath $envPath) {
  if ($line -match '^\s*(SUPABASE_URL|SUPABASE_PUBLISHABLE_KEY|GOOGLE_SERVER_CLIENT_ID)\s*=\s*(.*?)\s*$') {
    $values[$matches[1]] = $matches[2].Trim('"').Trim("'")
  }
}

$url = $values['SUPABASE_URL']
$key = $values['SUPABASE_PUBLISHABLE_KEY']
if ($url -notmatch '^https://[a-z0-9-]+\.supabase\.co$') {
  throw 'SUPABASE_URL in .env is missing or invalid.'
}
if ($key -notmatch '^sb_publishable_[A-Za-z0-9_-]+$') {
  throw 'SUPABASE_PUBLISHABLE_KEY in .env is missing or is not a publishable key. Refusing to pass a secret key to Flutter.'
}

$jsonValues = [ordered]@{
  SUPABASE_URL = $url
  SUPABASE_PUBLISHABLE_KEY = $key
}
$googleClientId = $values['GOOGLE_SERVER_CLIENT_ID']
if ($googleClientId) {
  $jsonValues['GOOGLE_SERVER_CLIENT_ID'] = $googleClientId
}
$json = $jsonValues | ConvertTo-Json
[System.IO.File]::WriteAllText(
  $configPath,
  $json,
  [System.Text.UTF8Encoding]::new($false)
)
if ($googleClientId) {
  Write-Output 'Flutter config is ready (Supabase + Google server client ID).'
} else {
  Write-Output 'Flutter Supabase config is ready (URL and publishable key only).'
}
