# 调整 Linux 桌面（XFCE）的界面缩放
# 用法: desktop-scale.ps1            → 默认 2 倍（推荐）
#       desktop-scale.ps1 -Scale 1.5 → 1.5 倍
#       desktop-scale.ps1 -Dpi 192   → 直接指定 DPI
#       desktop-scale.ps1 -Show      → 只看当前值
param([double]$Scale = 0, [int]$Dpi = 0, [switch]$Show)
$ErrorActionPreference = "Continue"
$root = $PSScriptRoot
$localTemp = Join-Path $root "tmp"
if (-not (Test-Path $localTemp)) { New-Item -ItemType Directory -Path $localTemp -Force | Out-Null }
$env:TEMP = $localTemp
$env:TMP = $localTemp

$adb = Join-Path (Split-Path $root -Parent) "scrcpy-win64-v5.0.1\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }

if ($Dpi -eq 0) {
    if ($Scale -eq 0) { $Scale = 2.0 }
    $Dpi = [int][math]::Round(96 * $Scale)
}

function Run-Remote([string]$body) {
    $script = @"
export HOME=/data/data/com.termux/files/home
export PREFIX=/data/data/com.termux/files/usr
export PATH=`$PREFIX/bin:`$PATH
export LD_LIBRARY_PATH=`$PREFIX/lib
export DISPLAY=:0
$body
"@
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($script))
    return ((& $adb -d shell "run-as com.termux sh -c 'echo $b64 | base64 -d > files/home/.scale.sh; sh files/home/.scale.sh'" 2>&1) -join "`n")
}

if ($Show) {
    Write-Host "=== 当前 Linux 桌面缩放 ==="
    Write-Host (Run-Remote 'echo "xsettings Xft/DPI: $(xfconf-query -c xsettings -p /Xft/DPI 2>/dev/null)"; echo "xrdb Xft.dpi: $(xrdb -query 2>/dev/null | grep -i xft.dpi)"; echo "虚拟屏: $(xdpyinfo 2>/dev/null | grep dimensions)"')
    exit 0
}

Write-Host "[1/4] 目标 DPI: $Dpi  （约 $([math]::Round($Dpi / 96.0, 2)) 倍）"

Write-Host "[2/4] 写入 ~/.Xresources …"
$r1 = Run-Remote "printf 'Xft.dpi: $Dpi\nXft.antialias: 1\nXft.hinting: 1\nXft.rgba: rgb\n' > `$HOME/.Xresources; DISPLAY=:0 xrdb -merge `$HOME/.Xresources; echo ok"
Write-Host ("      " + ($r1 -replace "\s+", " ").Trim())

Write-Host "[3/4] 写入 xfconf（GTK 应用实时生效）…"
$dpiVal = $Dpi * 1024
$r2 = Run-Remote @"
xfconf-query -c xsettings -p /Xft/DPI -s $dpiVal 2>/dev/null || xfconf-query -c xsettings -p /Xft/DPI -n -t int -s $dpiVal
xfconf-query -c xsettings -p /Gtk/WindowScalingFactor -s 1 2>/dev/null || xfconf-query -c xsettings -p /Gtk/WindowScalingFactor -n -t int -s 1
echo "Xft/DPI=`$(xfconf-query -c xsettings -p /Xft/DPI)"
"@
Write-Host ("      " + ($r2 -replace "\s+", " ").Trim())

Write-Host "[4/4] 重启面板（任务栏/菜单跟着变大）…"
$r3 = Run-Remote "pkill -f xfce4-panel; sleep 1; (nohup DISPLAY=:0 xfce4-panel >/dev/null 2>&1 &); sleep 2; pgrep -f xfce4-panel >/dev/null && echo 'panel restarted' || echo 'panel not running'"
Write-Host ("      " + ($r3 -replace "\s+", " ").Trim())

Write-Host ""
Write-Host "完成。"
Write-Host "  · 已经打开的 GTK 程序（终端、文件管理器等）可能要重开一次才会变"
Write-Host "  · 觉得太大/太小：desktop-scale.ps1 -Scale 1.5  或  -Scale 2.5"
Write-Host "  · 看当前值：desktop-scale.ps1 -Show"
