param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FlutterArgs
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'prepare_flutter_config.ps1') -ProjectRoot $projectRoot
Push-Location $projectRoot
try {
  & flutter build apk --dart-define-from-file=.env.flutter.json @FlutterArgs
  exit $LASTEXITCODE
}
finally {
  Pop-Location
}
