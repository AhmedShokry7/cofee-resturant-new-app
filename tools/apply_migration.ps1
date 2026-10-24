param(
  [Parameter(Mandatory = $true)][string]$SqlFile,
  [Parameter(Mandatory = $true)][string]$Version,
  [Parameter(Mandatory = $true)][string]$Name,
  [switch]$Commit
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'sbquery.ps1')

function Split-SqlStatements([string]$text) {
  $stmts = New-Object System.Collections.Generic.List[string]
  $sb = New-Object System.Text.StringBuilder
  $i = 0
  $len = $text.Length
  $inSingle = $false
  $inLineComment = $false
  $inBlockComment = $false
  $dollarTag = $null

  while ($i -lt $len) {
    $c = $text[$i]
    $two = $text.Substring($i, [Math]::Min(2, $len - $i))

    if ($inLineComment) {
      [void]$sb.Append($c)
      if ($c -eq "`n") { $inLineComment = $false }
      $i++; continue
    }
    if ($inBlockComment) {
      if ($two -eq '*/') { [void]$sb.Append('*'); $i += 2; $inBlockComment = $false; continue }
      $i++; continue
    }
    if ($dollarTag -ne $null) {
      $tagLen = $dollarTag.Length
      if (($len - $i) -ge $tagLen -and $text.Substring($i, $tagLen) -eq $dollarTag) {
        [void]$sb.Append($dollarTag); $i += $tagLen; $dollarTag = $null; continue
      }
      [void]$sb.Append($c); $i++; continue
    }
    if ($inSingle) {
      [void]$sb.Append($c)
      if ($c -eq "'") {
        if ($text[$i+1] -eq "'") { [void]$sb.Append("'"); $i += 2; continue }
        $inSingle = $false
      }
      $i++; continue
    }

    if ($two -eq '--') { $inLineComment = $true; [void]$sb.Append($two); $i += 2; continue }
    if ($two -eq '/*') { $inBlockComment = $true; [void]$sb.Append($two); $i += 2; continue }
    if ($c -eq "'") { $inSingle = $true; [void]$sb.Append($c); $i++; continue }
    if ($c -eq '$') {
      $m = [regex]::Match($text.Substring($i), '^\$[A-Za-z_0-9]*\$')
      if ($m.Success) {
        $dollarTag = $m.Value
        [void]$sb.Append($m.Value); $i += $m.Length; continue
      }
    }

    if ($c -eq ';') {
      $stmt = $sb.ToString().Trim()
      if ($stmt.Length -gt 0) { $stmts.Add($stmt) }
      [void]$sb.Clear()
      $i++; continue
    }

    [void]$sb.Append($c); $i++
  }

  $tail = $sb.ToString().Trim()
  if ($tail.Length -gt 0) { $stmts.Add($tail) }

  $clean = @()
  foreach ($s in $stmts) {
    $lines = $s -split "`n" | Where-Object { $_ -notmatch '^\s*--' -and $_.Trim() -ne '' }
    if ($lines.Count -gt 0) { $clean += ($lines -join "`n") }
  }
  return $clean
}

$text = Get-Content -Path $SqlFile -Raw -Encoding UTF8
$statements = Split-SqlStatements $text
Write-Host "File: $SqlFile -> $($statements.Count) statement(s)"

$escaped = $statements | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }
$arrayLiteral = 'ARRAY[' + ($escaped -join ',') + ']::text[]'

$ledger = "insert into supabase_migrations.schema_migrations (version, name, statements) values ('$Version', '$Name', $arrayLiteral);"

$sql = "begin;`n" + $text + "`n" + $ledger
if ($Commit) { $sql += "`ncommit;" }

$res = Invoke-SbQuery -Sql $sql
if ($res -like 'ERR:*') {
  Write-Host "FAILED (nothing was applied)" -ForegroundColor Red
  Write-Host $res
  exit 1
}
Write-Host "OK: $Version $Name applied"
if ($Commit) { Write-Host "committed" } else { Write-Host "rolled back (dry run)" }
