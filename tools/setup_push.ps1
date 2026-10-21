# Sets the Firebase service account of the push as a secret of the project and
# then checks that a push really leaves the app.
#
# The key file is the one downloaded from
#   Firebase console -> Project settings -> Service accounts ->
#   Generate new private key
# It holds a private key, so it is used here and nowhere else: the file is
# read, written to a temporary env file for the CLI, and that file is deleted
# again before the script ends. The key never enters the repository.
#
# Usage:
#   .\tools\setup_push.ps1 -KeyFile "$env:USERPROFILE\Downloads\firebase-adminsdk-xxxx.json"
#   .\tools\setup_push.ps1 -KeyJson '<the whole json of the key>'
param(
  [string]$KeyFile,
  [string]$KeyJson,
  [string]$Email = 'customer.a@test.local'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $projectRoot '.env'

if (-not $KeyFile -and -not $KeyJson) {
  throw 'Give the key file with -KeyFile or the key itself with -KeyJson.'
}
if ($KeyFile -and -not (Test-Path -LiteralPath $KeyFile)) {
  throw "Key file not found: $KeyFile"
}
if (-not (Test-Path -LiteralPath $envFile)) {
  throw "Missing $envFile"
}

$envValues = @{}
foreach ($line in Get-Content -LiteralPath $envFile) {
  if ($line -match '^\s*([A-Z_]+)\s*=\s*(.*?)\s*$') {
    $envValues[$matches[1]] = $matches[2].Trim('"').Trim("'")
  }
}

$supabaseUrl = $envValues['SUPABASE_URL']
$accessToken = $envValues['SUPABASE_ACCESS_TOKEN']
if (-not $supabaseUrl -or -not $accessToken) {
  throw '.env is missing SUPABASE_URL or SUPABASE_ACCESS_TOKEN.'
}
$projectRef = if ($envValues['SUPABASE_PROJECT_REF']) {
  $envValues['SUPABASE_PROJECT_REF']
} else {
  ($supabaseUrl -replace '^https?://', '').Split('.')[0]
}

# The key file has to be the one of the Firebase project of the app.
$rawKey = if ($KeyJson) { $KeyJson } else { Get-Content -LiteralPath $KeyFile -Raw -Encoding UTF8 }
$key = $rawKey | ConvertFrom-Json
foreach ($field in @('project_id', 'client_email', 'private_key')) {
  if (-not $key.$field) {
    throw "The key file has no $field. Is it a service account key of the Firebase project?"
  }
}
Write-Host "Service account : $($key.client_email)"
Write-Host "Firebase project: $($key.project_id)"

# The CLI reads NAME=VALUE pairs from a file, which avoids the quoting trouble
# of a JSON value with newlines and quotes in it.
$tempEnvFile = Join-Path ([System.IO.Path]::GetTempPath()) ("push-secret-" + [guid]::NewGuid().ToString('N') + '.env')
try {
  $compact = ($key | ConvertTo-Json -Depth 10 -Compress)
  Set-Content -LiteralPath $tempEnvFile -Value ("FIREBASE_SERVICE_ACCOUNT=" + $compact) -Encoding UTF8 -NoNewline

  Write-Host ''
  Write-Host 'Setting the secret on the project...'
  & supabase secrets set --env-file $tempEnvFile --project-ref $projectRef
  if ($LASTEXITCODE -ne 0) {
    throw "supabase secrets set failed with exit code $LASTEXITCODE"
  }
} finally {
  # The file holds a private key. It must not survive the script.
  if (Test-Path -LiteralPath $tempEnvFile) {
    Remove-Item -LiteralPath $tempEnvFile -Force
  }
}

Write-Host ''
Write-Host 'Checking the whole push...'
Push-Location $projectRoot
try {
  & node (Join-Path $PSScriptRoot 'check_push.mjs') $Email
  $code = $LASTEXITCODE
} finally {
  Pop-Location
}

if ($code -ne 0) {
  exit $code
}
Write-Host ''
Write-Host 'The push is live. Test it on the phone: change the status of an order'
Write-Host 'while the app is closed.'
