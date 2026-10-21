param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FlutterArgs
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'prepare_flutter_config.ps1') -ProjectRoot $projectRoot
Push-Location $projectRoot
try {
  # Gradle writes its warnings to the error stream. They are not failures, so
  # the strict error handling is switched off around the build and the exit
  # code decides whether the build worked.
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  & flutter build apk --dart-define-from-file=.env.flutter.json @FlutterArgs
  $buildExitCode = $LASTEXITCODE
  $ErrorActionPreference = $previous
  exit $buildExitCode
}
finally {
  Pop-Location
}
