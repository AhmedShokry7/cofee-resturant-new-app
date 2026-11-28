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
  if ($line -match '^\s*(SUPABASE_URL|SUPABASE_PUBLISHABLE_KEY|GOOGLE_SERVER_CLIENT_ID|MOYASAR_PUBLISHABLE_KEY|MOYASAR_STC_PAY_ENABLED|MOYASAR_APPLE_PAY_MERCHANT_ID|MOYASAR_SAMSUNG_PAY_SERVICE_ID|MOYASAR_MERCHANT_NAME|USE_MOYASAR)\s*=\s*(.*?)\s*$') {
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
$moyasarPublicKey = $values['MOYASAR_PUBLISHABLE_KEY']
$useMoyasar = $values['USE_MOYASAR']
if ($useMoyasar -eq 'true') {
  if ($moyasarPublicKey -notmatch '^pk_test_[A-Za-z0-9_-]+$') {
    throw 'USE_MOYASAR=true requires a Moyasar pk_test_ publishable key.'
  }
  $jsonValues['MOYASAR_PUBLISHABLE_KEY'] = $moyasarPublicKey
  $jsonValues['USE_MOYASAR'] = 'true'
} elseif ($useMoyasar -and $useMoyasar -ne 'false') {
  throw 'USE_MOYASAR must be true or false.'
}
foreach ($publicSetting in @('MOYASAR_STC_PAY_ENABLED','MOYASAR_APPLE_PAY_MERCHANT_ID','MOYASAR_SAMSUNG_PAY_SERVICE_ID','MOYASAR_MERCHANT_NAME')) {
  if ($values[$publicSetting]) { $jsonValues[$publicSetting] = $values[$publicSetting] }
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
