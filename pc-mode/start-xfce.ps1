# 启动 XFCE Linux 桌面并显示到虚拟屏上（一键）
# 用法: start-xfce.ps1           启动/重启
#       start-xfce.ps1 -Attach   只把已运行的桌面切回前台（不重启）
#       start-xfce.ps1 -Stop     停掉
param([switch]$Stop, [switch]$Attach)

$ErrorActionPreference = "Continue"
if (-not $Stop -and -not $Attach) { Set-Content -Path (Join-Path $PSScriptRoot "last-mode.txt") -Value "desktop" -Encoding ASCII }

$localTemp = Join-Path $PSScriptRoot "tmp"
if (-not (Test-Path $localTemp)) { New-Item -ItemType Directory -Path $localTemp -Force | Out-Null }
$env:TEMP = $localTemp
$env:TMP = $localTemp

$adb = Join-Path (Split-Path $PSScriptRoot -Parent) "scrcpy-win64-v5.0.1\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }

$vdFile = Join-Path $localTemp "vd-id.txt"
function Get-TargetVd {
    $saved = 0
    if (Test-Path $vdFile) {
        $raw = (Get-Content $vdFile -Raw -ErrorAction SilentlyContinue).Trim()
        if ($raw -match '^\d+$') { $saved = [int]$raw }
    }
    $line = ((& $adb -d shell "dumpsys display | grep -o -E 'displayId [0-9]+'" 2>&1) -join " ")
    $nums = [regex]::Matches($line, 'displayId (\d+)') | ForEach-Object { [int]$_.Groups[1].Value }
    $valid = $nums | Where-Object { $_ -ne 0 }
    if ($saved -ne 0 -and ($valid -contains $saved)) { return $saved }
    return (($valid | Sort-Object | Select-Object -Last 1))
}
$kill = @'
run-as com.termux sh -c 'for p in xfce4-session xfwm4 xfdesktop xfce4-panel xfce4-power-manager xfce4-notifyd lxqt-panel lxqt-notificationd lxqt-powermanagement pcmanfm-qt openbox termux-x11; do pkill -9 -f \pc-mode\start-xfce.ps1 2>/dev/null; done; sleep 2; echo stopped'
'@

if ($Stop) {
    & $adb -d shell $kill
    Write-Host "XFCE 已停止"
    exit 0
}

if ($Attach) {
    $vd = Get-TargetVd
    if (-not $vd) { Write-Host "[!] 没有虚拟屏"; exit 1 }
    # 关掉占位 App（Chrome），否则它会压在桌面上面
    & $adb -d shell "am force-stop com.android.chrome" 2>&1 | Out-Null
    Start-Sleep -Seconds 1
    & $adb -d shell "am start --display $vd --windowingMode 1 -n com.termux.x11/.MainActivity" 2>&1 | Out-Null
    $focus = Join-Path $PSScriptRoot "focus-scrcpy.ps1"
    if (Test-Path $focus) { & powershell -NoProfile -ExecutionPolicy Bypass -File $focus | Out-Null }
    Write-Host "已切回 Linux 桌面"
    exit 0
}

& $adb -d shell "run-as com.termux sh -c 'echo xfce > files/home/.desktop-kind'" 2>&1 | Out-Null
Write-Host "[1/3] 停掉旧的 XFCE 会话..."
& $adb -d shell $kill | Out-Null
Start-Sleep -Seconds 2

Write-Host "[2/3] 后台启动 termux-x11 + XFCE（setsid 脱离 adb shell）..."
$start = @'
run-as com.termux setsid sh -c 'export HOME=/data/data/com.termux/files/home; export PATH=/data/data/com.termux/files/usr/bin:$PATH; export LD_LIBRARY_PATH=/data/data/com.termux/files/usr/lib; nohup bash $HOME/start-xfce.sh > $HOME/boot.log 2>&1 </dev/null &'
'@
& $adb -d shell $start | Out-Null
Start-Sleep -Seconds 8

$alive = (& $adb -d shell "ps -A -o NAME | grep -c -E 'xfce4-session|termux-x11'" 2>$null) -join ""
Write-Host ("     进程数: " + $alive.Trim())

# 找虚拟屏
$vd = Get-TargetVd
if (-not $vd) { Write-Host "[!] 没有虚拟屏，先跑 2-start-pc.bat"; exit 1 }

Write-Host "[3/3] 在虚拟屏 $vd 上全屏打开 Termux:X11..."
# Chrome 只是 2-start-pc.bat 里用来占住虚拟屏的占位 App，先关掉它，
# 否则它会压在新开的 X11 桌面上（Chrome 会自己恢复标签页）
& $adb -d shell "am force-stop com.android.chrome" 2>&1 | Out-Null
Start-Sleep -Seconds 2
& $adb -d shell "am start --display $vd --windowingMode 1 -n com.termux.x11/.MainActivity" 2>&1 | Out-Null
Start-Sleep -Seconds 4
# 把投屏窗口拉到最前
$focus = Join-Path $PSScriptRoot "focus-scrcpy.ps1"
if (Test-Path $focus) { & powershell -NoProfile -ExecutionPolicy Bypass -File $focus | Out-Null }
Write-Host "完成。鼠标现在可以直接拖窗口、双击标题栏最大化。"
