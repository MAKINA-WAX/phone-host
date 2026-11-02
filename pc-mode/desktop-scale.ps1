# 调整 Linux 桌面界面缩放（LXQt）
#   desktop-scale.ps1               → 默认 1.25 倍
#   desktop-scale.ps1 -Scale 1.5    → 更大
#   desktop-scale.ps1 -Scale 1.0    → 恢复原始
#   desktop-scale.ps1 -Show         → 查看当前值
param([double]$Scale = 0, [switch]$Show)
$ErrorActionPreference = "Continue"
$root = $PSScriptRoot
$localTemp = Join-Path $root "tmp"
if (-not (Test-Path $localTemp)) { New-Item -ItemType Directory -Path $localTemp -Force | Out-Null }
$env:TEMP = $localTemp
$env:TMP = $localTemp

$adb = Join-Path (Split-Path $root -Parent) "scrcpy-win64-v5.0.1\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }

$prelude = @'
export HOME=/data/data/com.termux/files/home
export PREFIX=/data/data/com.termux/files/usr
export PATH=$PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$PREFIX/lib
export DISPLAY=:0
export XDG_RUNTIME_DIR=$PREFIX/tmp
'@

function Run-Remote([string]$body) {
    $script = $prelude + "`n" + $body
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($script))
    return ((& $adb -d shell "run-as com.termux sh -c 'echo $b64 | base64 -d > files/home/.scale.sh; sh files/home/.scale.sh'" 2>&1) -join "`n")
}

if ($Show) {
    $b = @'
echo "UI_SCALE       : $(grep '^UI_SCALE=' $HOME/start-lxqt.sh | cut -d= -f2)"
P=$(pgrep -f lxqt-panel | head -1)
if [ -n "$P" ]; then echo "QT_SCALE_FACTOR: $(tr '\0' '\n' < /proc/$P/environ | grep '^QT_SCALE_FACTOR=' | cut -d= -f2)"; fi
echo "panelSize      : $(grep -E '^panelSize' $HOME/.config/lxqt/panel.conf | head -1 | cut -d= -f2)"
echo "iconSize       : $(grep -E '^iconSize' $HOME/.config/lxqt/panel.conf | head -1 | cut -d= -f2)"
echo "font           : $(grep '^font=' $HOME/.config/lxqt/lxqt.conf | cut -d= -f2)"
echo "Xft.dpi        : $(xrdb -query 2>/dev/null | grep -i xft.dpi | awk '{print $2}')"
echo "Firefox scale  : $(grep -h devPixelsPerPx $HOME/.config/mozilla/firefox/*/user.js 2>/dev/null | grep -o '"[0-9.]*"')"
'@
    Write-Host "=== 当前界面缩放 ==="
    Write-Host (Run-Remote $b)
    exit 0
}

if ($Scale -le 0) { $Scale = 1.25 }

Write-Host "[1/3] 写入缩放配置（$Scale 倍）…"
$r1 = Run-Remote ("bash `$HOME/apply-scale.sh " + $Scale)
Write-Host ($r1.Trim() -replace "`r", "")
if ($LASTEXITCODE -ne 0 -or $r1 -match "No such file") {
    Write-Host "      !! apply-scale.sh 不存在，先部署：phone\apply-scale.sh"
    exit 1
}

Write-Host "[2/3] 重启桌面让面板/字体生效（约 15 秒）…"
$startScript = Join-Path $root "start-lxqt.ps1"
& powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $startScript | Out-Null
Start-Sleep -Seconds 6

Write-Host "[3/3] 验证…"
$r3 = Run-Remote 'echo "UI_SCALE=$(grep ''^UI_SCALE='' $HOME/start-lxqt.sh | cut -d= -f2)  panel=$(grep -E ''^panelSize'' $HOME/.config/lxqt/panel.conf | head -1 | cut -d= -f2)px  font=$(grep ''^font='' $HOME/.config/lxqt/lxqt.conf | cut -d= -f2)"'
if ($r3) { Write-Host ("      " + ($r3 -replace "\s+", " ").Trim()) }

Write-Host ""
Write-Host "完成。太大/太小: -Scale 1.5 或 -Scale 1.0 ；查看: -Show"
