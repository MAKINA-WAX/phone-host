# 关闭软件（全部退出）：停投屏、停守护、停托盘、禁用计划任务
# 与"收工"的区别：收工只是暂停（托盘和守护还在，随时能用），这个是整个退出
$ErrorActionPreference = "Continue"
$root = $PSScriptRoot
$localTemp = Join-Path $root "tmp"
if (-not (Test-Path $localTemp)) { New-Item -ItemType Directory -Path $localTemp -Force | Out-Null }
$env:TEMP = $localTemp
$env:TMP = $localTemp

$adb = Join-Path (Split-Path $root -Parent) "scrcpy-win64-v5.0.1\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }

Write-Host "== 关闭软件 =="

# 1) 标记暂停（防止任何组件被意外拉起）
Set-Content -Path (Join-Path $root "paused.flag") -Value "shutdown" -Encoding ASCII
Write-Host "[1/5] 已写入 paused.flag"

# 2) 关投屏
Get-Process scrcpy -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
& $adb -d shell "pkill -f com.genymobile.scrcpy" 2>&1 | Out-Null
Write-Host "[2/5] 投屏已关闭"

# 3) 停守护
$wp = (Get-Content (Join-Path $localTemp "watch-reconnect.pid") -Raw -ErrorAction SilentlyContinue)
if ($wp) {
    $wp = $wp.Trim()
    if ($wp -match '^\d+$') {
        Stop-Process -Id ([int]$wp) -Force -ErrorAction SilentlyContinue
        Write-Host "[3/5] 守护已停止 (pid $wp)"
    }
} else { Write-Host "[3/5] 守护未运行" }
Remove-Item (Join-Path $localTemp "watch-reconnect.pid") -ErrorAction SilentlyContinue

# 4) 停托盘
$tp = (Get-Content (Join-Path $localTemp "tray.pid") -Raw -ErrorAction SilentlyContinue)
if ($tp) {
    $tp = $tp.Trim()
    if ($tp -match '^\d+$') {
        Stop-Process -Id ([int]$tp) -Force -ErrorAction SilentlyContinue
        Write-Host "[4/5] 托盘已退出 (pid $tp)"
    }
} else { Write-Host "[4/5] 托盘未运行" }
Remove-Item (Join-Path $localTemp "tray.pid") -ErrorAction SilentlyContinue

# 5) 禁用计划任务（否则 5 分钟后守护会自己回来）
& schtasks /change /tn "PhoneHost-WatchReconnect" /disable 2>&1 | Out-Null
Write-Host "[5/5] 计划任务已禁用（下次跑 启动.bat 会自动重新启用）"

Write-Host ""
Write-Host "全部已关闭。要再打开：双击 启动.bat"
Start-Sleep -Seconds 2
