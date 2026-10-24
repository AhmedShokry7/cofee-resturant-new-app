param(
  # The PostgreSQL binaries. Any 15+ installation works; the harness never
  # touches a production database.
  [string]$PgBin = "$env:LOCALAPPDATA\Temp\opencode\pg\pgsql\bin",
  [string]$WorkDir = "$env:LOCALAPPDATA\Temp\opencode\db_replay",
  [int]$Port = 55441,
  # The seed folder is gone: the demo catalogue was removed (136) and the
  # reference data became a migration (137). The step stays for the case
  # where a seed folder is added again.
  [bool]$IncludeSeed = $true
)

$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$migrations = Join-Path $repo 'supabase\migrations'
$seedDir = Join-Path $repo 'supabase\seed'

New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
$dataDir = Join-Path $WorkDir 'data'
$logFile = Join-Path $WorkDir 'postgres.log'
$report = Join-Path $WorkDir 'replay-report.txt'
$psql = Join-Path $PgBin 'psql.exe'
$pgCtl = Join-Path $PgBin 'pg_ctl.exe'

$env:PGHOST = '127.0.0.1'
$env:PGPORT = "$Port"
$env:PGUSER = 'postgres'
$env:PGPASSWORD = ''

if (Test-Path -LiteralPath $dataDir) {
  Remove-Item -LiteralPath $dataDir -Recurse -Force
}

Write-Host "== initdb =="
& (Join-Path $PgBin 'initdb.exe') -D $dataDir -U postgres --auth=trust -E UTF8 | Out-Null
if ($LASTEXITCODE -ne 0) { throw "initdb failed" }

Write-Host "== start =="
# The postmaster is started directly and detached: `pg_ctl start` keeps the
# console attached on Windows and never returns, and `pg_ctl -w` can wait
# forever for the readiness message.  The readiness is polled with psql
# instead.  wal_level=logical is needed by the `supabase_realtime` publication.
$outLog = Join-Path $WorkDir 'postgres.out.log'
$errLog = Join-Path $WorkDir 'postgres.err.log'
Start-Process -FilePath (Join-Path $PgBin 'postgres.exe') `
  -ArgumentList @('-D', $dataDir, '-p', "$Port", '-c', 'wal_level=logical', '-c', 'listen_addresses=127.0.0.1') `
  -RedirectStandardOutput $outLog -RedirectStandardError $errLog -WindowStyle Hidden | Out-Null
$ready = $false
for ($i = 0; $i -lt 90; $i++) {
  & $psql -d postgres -c 'select 1' 2>&1 | Out-Null
  if ($LASTEXITCODE -eq 0) { $ready = $true; break }
  Start-Sleep -Seconds 1
}
if (-not $ready) { throw "postgres did not become ready" }
Write-Host "   ready"

$lines = @("Replayed at $(Get-Date -Format o)", "")
$failures = 0

function Add-Line([string]$Text) {
  $script:lines += $Text
  Write-Host $Text
}

function Invoke-Script([string]$File, [string]$Label) {
  # psql writes its notices to stderr. Redirected, they become error records,
  # and the script stops on the first notice, so the preference is relaxed
  # around the call and the exit code decides whether the file worked.
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'

  # pg_cron cannot be installed on a vanilla PostgreSQL, and the platform
  # provides it on Supabase. The statement is neutralised for the replay; the
  # cron.schedule() stand-in of the bootstrap keeps the rest of the file
  # working.
  $text = [System.IO.File]::ReadAllText($File)
  if ($text -match 'create extension if not exists pg_cron;') {
    $text = $text -replace 'create extension if not exists pg_cron;', '-- create extension if not exists pg_cron;  -- not installable in the isolated harness'
    $staged = Join-Path $WorkDir ([System.IO.Path]::GetFileName($File))
    [System.IO.File]::WriteAllText($staged, $text)
    $out = & $psql -v ON_ERROR_STOP=1 -d postgres -f $staged 2>&1
  } else {
    $out = & $psql -v ON_ERROR_STOP=1 -d postgres -f $File 2>&1
  }
  $code = $LASTEXITCODE
  $ErrorActionPreference = $previous
  if ($code -ne 0) {
    $script:failures++
    Add-Line "FAIL $Label"
    $out | Select-Object -First 12 | ForEach-Object { Add-Line "     $_" }
  } else {
    Add-Line "ok   $Label"
  }
}

try {
  Write-Host "== bootstrap =="
  Invoke-Script (Join-Path $PSScriptRoot 'bootstrap.sql') 'bootstrap'
  # ---------------------------------------------------------------------------
  # The chain, in the order the Supabase CLI applies it: the numeric prefix
  # decides, and a file whose name does not start with digits is skipped.
  # ---------------------------------------------------------------------------
  $files = Get-ChildItem -LiteralPath $migrations -Filter '*.sql' | Where-Object {
    $_.Name -match '^([0-9]+)_(.*)\.sql$'
  } | Sort-Object { [int]($_.Name -replace '^([0-9]+)_.*$', '$1') }, { $_.Name }

  $skipped = Get-ChildItem -LiteralPath $migrations -Filter '*.sql' | Where-Object {
    $_.Name -notmatch '^([0-9]+)_(.*)\.sql$'
  } | Select-Object -ExpandProperty Name

  Add-Line "Files applied: $($files.Count)"
  Add-Line ""

  # Two files with the same version: the CLI would write the same row twice
  # and abort the whole push.
  $duplicates = $files | Group-Object { $_.Name -replace '^([0-9]+)_.*$', '$1' } |
    Where-Object { $_.Count -gt 1 }
  if ($duplicates) {
    $failures++
    foreach ($group in $duplicates) {
      Add-Line "FAIL duplicate migration version $($group.Name): $($group.Group.Name -join ', ')"
    }
  } else {
    Add-Line "ok   every migration version is used once"
  }
  Add-Line ""

  foreach ($file in $files) {
    Invoke-Script $file.FullName $file.Name
    $version = $file.Name -replace '^([0-9]+)_.*$', '$1'
    & $psql -d postgres -c "insert into supabase_migrations.schema_migrations (version, name, statements) values ('$version', '$($file.Name)', '{}') on conflict (version) do nothing" 2>&1 | Out-Null
  }
  Add-Line ""
  Add-Line "Skipped by the CLI (the name does not match ^([0-9]+)_(.*).sql$):"
  foreach ($name in $skipped) { Add-Line "     $name" }

  if ($IncludeSeed -and (Test-Path -LiteralPath $seedDir)) {
    Add-Line ""
    Add-Line "== seed =="
    foreach ($seed in (Get-ChildItem -LiteralPath $seedDir -Filter '*.sql' | Sort-Object Name)) {
      Invoke-Script $seed.FullName "seed/$($seed.Name)"
    }
  } elseif ($IncludeSeed) {
    Add-Line ""
    Add-Line "== seed == (no seed folder: the reference data is migration 137)"
  }

  Add-Line ""
  Add-Line "== assertions =="
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $out = & $psql -v ON_ERROR_STOP=1 -v "applied=$($files.Count)" -d postgres -f (Join-Path $PSScriptRoot 'assertions.sql') 2>&1
  $ErrorActionPreference = $previous
  $out | ForEach-Object { Add-Line "     $_" }
  if ($LASTEXITCODE -ne 0) { $failures++ }

  Add-Line ""
  Add-Line "== the behaviour tests =="
  $testFiles = @('cancel_order_test.sql')
  foreach ($testFile in $testFiles) {
    $testPath = Join-Path $repo "supabase\tests\$testFile"
    if (-not (Test-Path $testPath)) { continue }
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & $psql -v ON_ERROR_STOP=1 -d postgres -f $testPath 2>&1
    $ErrorActionPreference = $previous
    if ($LASTEXITCODE -ne 0) {
      $failures++
      Add-Line "FAIL tests/$testFile"
      $out | Select-Object -Last 12 | ForEach-Object { Add-Line "     $_" }
    } else {
      Add-Line "ok   tests/$testFile"
    }
  }

  Add-Line ""
  Add-Line "Failures: $failures"
  $lines | Out-File -FilePath $report -Encoding utf8
  if ($failures -gt 0) { exit 1 }
} catch {
  Add-Line ""
  Add-Line "ERROR: $($_.Exception.Message)"
  Add-Line $_.ScriptStackTrace
  $lines | Out-File -FilePath $report -Encoding utf8
  exit 2
} finally {
  try { & $pgCtl -D $dataDir -m fast stop | Out-Null } catch { }
}
