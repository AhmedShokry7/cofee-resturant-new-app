<#
.SYNOPSIS
  إيقاف المعاينة الحيّة (تطبيق العميل + لوحة التحكم) وتحرير المنافذ.
#>
$ErrorActionPreference = 'SilentlyContinue'
$repoRoot = Split-Path -Parent $PSScriptRoot
$pidFile = Join-Path $repoRoot '.preview-logs\pids.txt'

if (Test-Path $pidFile) {
  Get-Content $pidFile | ForEach-Object {
    Write-Host "إيقاف العملية $_"
    Stop-Process -Id $_ -Force
  }
  Remove-Item $pidFile
} else {
  # بلا ملف معرّفات: أوقف ما يستمع على المنفذين.
  foreach ($port in 5000, 8080) {
    Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue |
      Select-Object -ExpandProperty OwningProcess -Unique |
      ForEach-Object { Write-Host "إيقاف $_ (منفذ $port)"; Stop-Process -Id $_ -Force }
  }
}
Write-Host '✅ توقفت المعاينة.'
