param(
  # Seconds the app is watched after launch.
  [int]$WatchSeconds = 45,

  # adb device id. Defaults to the only connected device.
  [string]$Device,

  # Build the release APK before checking it.
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

# adb writes warnings such as "Activity not started, intent has been delivered"
# to the error stream. They are not failures, so every adb call runs with the
# strict error handling switched off and the exit code decides.
function Invoke-Adb {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $output = & adb @Arguments 2>&1
  $code = $LASTEXITCODE
  $ErrorActionPreference = $previous
  if ($code -ne 0) { throw "adb $($Arguments -join ' ') failed with exit code $code." }
  return $output
}

function Resolve-Device {
  if ($Device) { return $Device }
  $ids = @(& adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '\sdevice$' } | ForEach-Object { ($_ -split '\s+')[0] })
  if ($ids.Count -eq 0) { throw 'No adb device is connected. Start an emulator or plug in a phone.' }
  if ($ids.Count -gt 1) { Write-Host "Several devices are connected: $($ids -join ', '). Using the first one." }
  return $ids[0]
}

function Find-PatternHits {
  param([string[]]$Lines, [string[]]$Patterns)
  $hits = @()
  foreach ($line in $Lines) {
    foreach ($pattern in $Patterns) {
      if ($line -match $pattern) { $hits += $line; break }
    }
  }
  return $hits
}

$deviceId = Resolve-Device
Write-Host "Device: $deviceId"

if (-not $SkipBuild) {
  Write-Host 'Building the release APK...'
  # The Gradle build writes warnings to the error stream. They are not
  # failures, so the strict error handling is switched off around it and the
  # exit code decides.
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  & (Join-Path $PSScriptRoot 'build_apk.ps1') --release 2>&1 |
    ForEach-Object { "$_" } |
    Where-Object { $_ -notmatch 'System\.Management\.Automation\.RemoteException' } |
    Select-Object -Last 4 |
    ForEach-Object { Write-Host "  $_" }
  $buildExitCode = $LASTEXITCODE
  $ErrorActionPreference = $previous
  if ($buildExitCode -ne 0) { throw "The release build failed with exit code $buildExitCode." }
}

$apk = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path -LiteralPath $apk)) { throw "The release APK is missing: $apk" }

Write-Host 'Installing...'
# An app signed with another key cannot be replaced in place. The old copy is
# removed first so the check also works after the signing key changed.
$previous = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
& adb -s $deviceId install -r $apk 2>&1 | Out-Null
$installExitCode = $LASTEXITCODE
$ErrorActionPreference = $previous
if ($installExitCode -ne 0) {
  Write-Host '  The installed copy was signed with another key. Removing it and installing again.'
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  & adb -s $deviceId uninstall com.example.new_coffee 2>&1 | Out-Null
  & adb -s $deviceId install -r $apk 2>&1 | Out-Null
  $installExitCode = $LASTEXITCODE
  $ErrorActionPreference = $previous
}
if ($installExitCode -ne 0) { throw 'The installation failed.' }

# The package id and the launcher activity are read from the APK itself, so
# the check keeps working when either one changes.
$packageId = (Invoke-Adb -s $deviceId shell pm list packages |
    Select-String -Pattern 'com\.example\.new_coffee' |
    ForEach-Object { ($_ -split ':')[1] } | Select-Object -First 1).ToString().Trim()
if (-not $packageId) { throw 'The app is not installed on the device after the installation step.' }

$launchActivity = (Invoke-Adb -s $deviceId shell "cmd package resolve-activity --brief $packageId" |
    Select-Object -Last 1).ToString().Trim()
if (-not $launchActivity -or $launchActivity -notmatch '/') {
  $launchActivity = (Invoke-Adb -s $deviceId shell "dumpsys package $packageId" |
      Select-String -Pattern "$packageId/[A-Za-z0-9_.]+MainActivity" |
      Select-Object -First 1).ToString().Trim()
}
if (-not $launchActivity) { throw 'The launcher activity could not be found.' }

Write-Host "Launching $launchActivity ..."
Invoke-Adb -s $deviceId logcat -c | Out-Null
Invoke-Adb -s $deviceId shell am force-stop $packageId | Out-Null
Start-Sleep -Seconds 2
Invoke-Adb -s $deviceId shell am start -n $launchActivity | Out-Null

Write-Host "Watching the log for $WatchSeconds seconds ..."
Start-Sleep -Seconds $WatchSeconds

Write-Host 'Reading the process id ...'
$appPid = (Invoke-Adb -s $deviceId shell pidof $packageId).ToString().Trim()
Write-Host "Process id: $appPid"
if (-not $appPid) {
  Write-Host 'RESULT: FAILED - the app is not running. It crashed on start.'
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  & adb -s $deviceId logcat -d 2>&1 |
    Select-String -Pattern 'FATAL EXCEPTION|AndroidRuntime|libc.*Fatal signal' |
    Select-Object -Last 20 |
    ForEach-Object { Write-Host "  $_" }
  $ErrorActionPreference = $previous
  exit 1
}

Write-Host 'Reading the log ...'
# The log is read without the argument splatting of Invoke-Adb: a splatted
# `logcat -d` inside a function blocks instead of returning.
$previous = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$log = & adb -s $deviceId logcat -d --pid=$appPid 2>&1
$ErrorActionPreference = $previous
Write-Host "Log lines: $($log.Count)"

# The patterns that must never appear in a release build that is shown to a
# customer. A crash, a missing plugin or a failing platform call is a bug
# that only shows up in release, because release is the only mode with R8.
$patterns = @(
  'E/flutter',
  'FATAL EXCEPTION',
  'NoSuchMethodError',
  'NoClassDefFoundError',
  'MissingPluginException',
  'PlatformException',
  'Unhandled Exception',
  'A RenderFlex overflowed',
  'Another exception was thrown',
  '\[Supabase\.init\]',
  '\[SharedPref\].*failed',
  '\[UncaughtError\]',
  '\[FlutterError\]'
)

$hits = Find-PatternHits -Lines $log -Patterns $patterns
if ($hits.Count -gt 0) {
  Write-Host ''
  Write-Host 'RESULT: FAILED - the release build logged errors:'
  $hits | Select-Object -Last 40 | ForEach-Object { Write-Host "  $_" }
  exit 1
}

Write-Host ''
Write-Host 'RESULT: OK - the release build started and logged no errors.'
exit 0
