<#
.SYNOPSIS
  تشغيل المحرر المرئي مع معاينة تطبيق العميل الحقيقية.

.DESCRIPTION
  يشغّل عمليتين معًا ويمنع تعارض المنافذ:
    1) تطبيق العميل في وضع المعاينة على http://localhost:5000
       (نقطة الدخول: lib/main_preview.dart — التطبيق الحقيقي نفسه داخل إطار الأدمن).
    2) لوحة التحكم على http://localhost:8080
       (المحرر المرئي يُظهر المعاينة الحيّة على الويب فقط).

  التحقق قبل التشغيل: المنفذان 5000 و8080 يجب أن يكونا حرّين، وإلا
  يفشل السكربت برسالة واضحة بدل خطأ flutter غامق.

  السجلات الحية:  .preview-logs/customer.log  و  .preview-logs/admin.log
  إيقاف كل شيء:    tools/stop_visual_preview.ps1

.EXAMPLE
  tools/run_visual_preview.ps1
#>
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$logsDir = Join-Path $repoRoot '.preview-logs'
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

function Test-PortFree([int]$Port) {
  $busy = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
  if ($busy) {
    $owner = (Get-Process -Id $busy[0].OwningProcess -ErrorAction SilentlyContinue).ProcessName
    Write-Host "✗ المنفذ $Port مشغول بعملية '$owner' (PID $($busy[0].OwningProcess))." -ForegroundColor Red
    Write-Host "  أوقفه أولًا: Stop-Process -Id $($busy[0].OwningProcess) أو tools/stop_visual_preview.ps1"
    exit 1
  }
}

Test-PortFree 5000
Test-PortFree 8080

# Flutter متاح؟
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Host '✗ flutter غير موجود في PATH.' -ForegroundColor Red
  exit 1
}

Write-Host '▶ تشغيل تطبيق العميل (وضع المعاينة) على 5000…'
$customer = Start-Process -FilePath 'flutter' `
  -ArgumentList 'run','--release','-d','web-server','--web-port','5000','--web-hostname','127.0.0.1','-t','lib/main_preview.dart' `
  -WorkingDirectory $repoRoot `
  -RedirectStandardOutput (Join-Path $logsDir 'customer.log') `
  -RedirectStandardError (Join-Path $logsDir 'customer.err.log') `
  -PassThru -WindowStyle Hidden

Write-Host '▶ تشغيل لوحة التحكم على 8080…'
$admin = Start-Process -FilePath 'flutter' `
  -ArgumentList 'run','--release','-d','web-server','--web-port','8080','--web-hostname','127.0.0.1' `
  -WorkingDirectory (Join-Path $repoRoot 'app\admin_app') `
  -RedirectStandardOutput (Join-Path $logsDir 'admin.log') `
  -RedirectStandardError (Join-Path $logsDir 'admin.err.log') `
  -PassThru -WindowStyle Hidden

# حفظ معرّفي العمليتين ليوقفهما سكربت الإيقاف.
@($customer.Id, $admin.Id) | Set-Content (Join-Path $logsDir 'pids.txt')

Write-Host ''
Write-Host 'بانتظار جاهزية الخادمين (قد يستغرق أول ترجمة دقائق)…'
$deadline = (Get-Date).AddMinutes(8)
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Seconds 5
  $c = Get-NetTCPConnection -LocalPort 5000 -State Listen -ErrorAction SilentlyContinue
  $a = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
  if ($c -and $a) { break }
  if ($customer.HasExited) { Write-Host '✗ توقف تشغيل تطبيق العميل — راجع .preview-logs/customer.err.log' -ForegroundColor Red; exit 1 }
  if ($admin.HasExited) { Write-Host '✗ توقف تشغيل لوحة التحكم — راجع .preview-logs/admin.err.log' -ForegroundColor Red; exit 1 }
}

if (-not ($c -and $a)) {
  Write-Host '✗ انتهت المهلة قبل جاهزية الخادمين — راجع السجلات في .preview-logs' -ForegroundColor Red
  exit 1
}

Write-Host ''
Write-Host '✅ الخادمان جاهزان:' -ForegroundColor Green
Write-Host '   لوحة التحكم:    http://localhost:8080   ← افتحها وسجّل دخولك'
Write-Host '   معاينة العميل:  http://localhost:5000   ← لا تفتحها يدويًا؛ الإطار يفعل'
Write-Host '   سجلات حية:      .preview-logs\'
Write-Host '   إيقاف كل شيء:   tools/stop_visual_preview.ps1'
Write-Host ''
Write-Host 'بعد تسجيل الدخول افتح «المحرر المرئي» — ستظهر معاينة تطبيق العميل الحقيقية داخل شاشة الهاتف.'
