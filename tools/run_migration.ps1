param(
  [Parameter(Mandatory = $true)][string]$SqlFile,
  [switch]$VerboseStatements,
  [switch]$NoExec
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'sbquery.ps1')

function Invoke-Sql([string]$sql) {
  $res = Invoke-SbQuery -Sql $sql
  if ($res -like 'ERR:*') { return @{ ok = $false; error = $res } }
  return @{ ok = $true; result = $res }
}

# Split SQL into statements, respecting dollar quotes ($tag$ ... $tag$),
# single quotes, and line/block comments.
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
      [void]$sb.Append($c)
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

    # not inside any special region
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

  # Drop statements that are only comments/whitespace
  $clean = @()
  foreach ($s in $stmts) {
    $stripped = $s
    # remove leading full-line comments
    $lines = $stripped -split "`n" | Where-Object { $_ -notmatch '^\s*--' -and $_.Trim() -ne '' }
    if ($lines.Count -gt 0) { $clean += ($lines -join "`n") }
  }
  return $clean
}

$text = Get-Content -Path $SqlFile -Raw -Encoding UTF8
$statements = Split-SqlStatements $text
Write-Host "File: $SqlFile -> $($statements.Count) statement(s)"

$failed = 0
$n = 0
foreach ($stmt in $statements) {
  $n++
  $preview = ($stmt -replace '\s+', ' ')
  if ($preview.Length -gt 90) { $preview = $preview.Substring(0, 90) + '...' }
  if ($NoExec) {
    Write-Host "  [$n] DRY $preview"
    continue
  }
  $res = Invoke-Sql $stmt
  if ($res.ok) {
    if ($VerboseStatements) { Write-Host "  [$n] OK   $preview" }
    else { Write-Host "  [$n] OK" }
  } else {
    $failed++
    Write-Host "  [$n] FAIL $preview" -ForegroundColor Red
    Write-Host "       $($res.error)" -ForegroundColor Red
    Write-Host "STATEMENT WAS:" -ForegroundColor Yellow
    Write-Host $stmt
    break
  }
}

Write-Host "---- $n/$($statements.Count) executed, $failed failed ----"
if ($failed -gt 0) { exit 1 }
