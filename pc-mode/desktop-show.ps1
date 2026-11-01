# 一键把"手机上已经跑起来的 Linux 桌面"显示到电脑上
# 逻辑：没有虚拟屏 → 先建屏（auto-start.ps1）；有屏 → 直接把 Termux:X11 铺上去（-Attach，不重启桌面）
$ErrorActionPreference = "Continue"
$root = $PSScriptRoot
$localTemp = Join-Path $root "tmp"
if (-not (Test-Path $localTemp)) { New-Item -ItemType Directory -Path $localTemp -Force | Out-Null }
$env:TEMP = $localTemp
$env:TMP = $localTemp

$adb = Join-Path (Split-Path $root -Parent) "scrcpy-win64-v5.0.1\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }

function Get-Vd {
    $ids = ((& $adb -d shell "dumpsys display | grep -o -E 'displayId [0-9]+'" 2>&1) -join " ")
    $nums = [regex]::Matches($ids, 'displayId (\d+)') | ForEach-Object { [int]$_.Groups[1].Value }
    $vd = ($nums | Where-Object { $_ -ne 0 } | Sort-Object | Select-Object -Last 1)
    return $vd
}
function Xfce-Running {
    $n = ((& $adb -d shell "ps -A -o NAME | grep -c -E 'xfce4-session|termux-x11'" 2>&1) -join "").Trim()
    return ($n -match '^\d+$' -and [int]$n -gt 0)
}

Write-Host "[1/3] 检查手机上的 Linux 桌面进程…"
if (-not (Xfce-Running)) {
    Write-Host "      没在跑 → 先在手机上启动它"
    $start = @'
run-as com.termux setsid sh -c 'export HOME=/data/data/com.termux/files/home; export PATH=/data/data/com.termux/files/usr/bin:$PATH; export LD_LIBRARY_PATH=/data/data/com.termux/files/usr/lib; nohup bash $HOME/start-xfce.sh > $HOME/boot.log 2>&1 </dev/null &'
'@
    & $adb -d shell $start 2>&1 | Out-Null
    Start-Sleep -Seconds 8
} else {
    Write-Host "      已在运行，直接接管显示"
}

Write-Host "[2/3] 检查虚拟屏…"
$vd = Get-Vd
if (-not $vd) {
    Write-Host "      没有虚拟屏 → 先建一块（会先起来一个投屏窗口）"
    $as = Join-Path $root "auto-start.ps1"
    if (Test-Path $as) { & powershell -NoProfile -ExecutionPolicy Bypass -File $as | Out-Null }
    Start-Sleep -Seconds 10
    $vd = Get-Vd
}
if (-not $vd) { Write-Host "[!] 还是没建出虚拟屏，先手动跑 2-start-pc.bat"; exit 1 }
Write-Host "      虚拟屏 displayId = $vd"

Write-Host "[3/3] 把桌面铺到虚拟屏上…"
$attach = Join-Path $root "start-xfce.ps1"
& powershell -NoProfile -ExecutionPolicy Bypass -File $attach -Attach
Write-Host "完成：Linux 桌面已经显示在电脑上了（鼠标可拖窗口，右键是桌面菜单）。"
