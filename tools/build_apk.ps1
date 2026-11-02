param(
  # `tools/build_apk.ps1 --debug` used to silently build a RELEASE apk:
  # PowerShell binds -Debug as its own common parameter before the script sees
  # it, so the flag never reached Flutter and the remaining-args array stayed
  # empty. The build type gets a name that cannot collide with a common
  # parameter, and the run says which apk it is making.
  [switch]$DebugBuild,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FlutterArgs
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'prepare_flutter_config.ps1') -ProjectRoot $projectRoot
Push-Location $projectRoot
try {
  $buildType = if ($DebugBuild) { '--debug' } else { '--release' }
  Write-Host "Building the $buildType apk (flutter build apk $buildType)"
  # Gradle writes its warnings to the error stream. They are not failures, so
  # the strict error handling is switched off around the build and the exit
  # code decides whether the build worked.
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $typeArgs = @($buildType)
  & flutter build apk $typeArgs --dart-define-from-file=.env.flutter.json @FlutterArgs
  $buildExitCode = $LASTEXITCODE
  $ErrorActionPreference = $previous
  exit $buildExitCode
}
finally {
  Pop-Location
}
