# 加固后台存活：把能通过 adb 改的开关全部拉满
# 用法: harden.ps1
$ErrorActionPreference = "Continue"

$localTemp = Join-Path $PSScriptRoot "tmp"
if (-not (Test-Path $localTemp)) { New-Item -ItemType Directory -Path $localTemp -Force | Out-Null }
$env:TEMP = $localTemp
$env:TMP = $localTemp

$adb = Join-Path (Split-Path $PSScriptRoot -Parent) "scrcpy-win64-v5.0.1\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }

$pkgs = @("com.termux", "com.termux.x11", "com.termux.api", "com.termux.boot", "com.termux.widget")
$ops = @("WAKE_LOCK", "START_FOREGROUND", "RUN_IN_BACKGROUND", "RUN_ANY_IN_BACKGROUND")

Write-Host "== 加固后台存活 ==" -ForegroundColor Cyan
foreach ($p in $pkgs) {
    $installed = ((& $adb -d shell "pm list packages $p" 2>&1) -join "") -match [regex]::Escape($p)
    if (-not $installed) { Write-Host "  跳过（未安装）: $p"; continue }
    foreach ($op in $ops) {
        $r = ((& $adb -d shell "cmd appops set $p $op allow" 2>&1) -join " ")
        if ($r -match "Error|Exception") { Write-Host "  [WARN] $p $op 失败" -ForegroundColor Yellow }
    }
    & $adb -d shell "am set-inactive $p false" 2>&1 | Out-Null
    & $adb -d shell "am set-standby-bucket $p active" 2>&1 | Out-Null
    & $adb -d shell "dumpsys deviceidle whitelist +$p" 2>&1 | Out-Null
    Write-Host "  [OK] $p：appops + 活跃桶 + Doze 白名单"
}

Write-Host "`n校验：" -ForegroundColor Cyan
foreach ($p in @("com.termux", "com.termux.x11")) {
    $b = ((& $adb -d shell "am get-standby-bucket $p" 2>&1) -join "").Trim()
    $w = ((& $adb -d shell "dumpsys deviceidle whitelist | grep -c $p" 2>&1) -join "").Trim()
    $a = ((& $adb -d shell "appops get $p | grep -cE 'WAKE_LOCK: allow|START_FOREGROUND: allow'" 2>&1) -join "").Trim()
    Write-Host ("  {0}: bucket={1} (5=ACTIVE)  whitelist={2}  appops命中={3}" -f $p, $b, $w, $a)
}
Write-Host "`n注意：MIUI 的「省电策略=无限制」「自启动」「最近任务下拉锁定」adb 改不了，仍需手点一次。" -ForegroundColor Yellow
