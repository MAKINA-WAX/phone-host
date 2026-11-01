# 在虚拟屏上打开一个 App
#   open-app.ps1 com.android.chrome            全屏模式（铺满 16:10，布局自动适配）
#   open-app.ps1 com.android.chrome -Windowed  小窗模式（freeform，可拖动/平铺）
param(
    [string]$Pkg,
    [switch]$Windowed
)

$ErrorActionPreference = "Continue"

$localTemp = Join-Path $PSScriptRoot "tmp"
if (-not (Test-Path $localTemp)) { New-Item -ItemType Directory -Path $localTemp -Force | Out-Null }
$env:TEMP = $localTemp
$env:TMP = $localTemp

$adb = Join-Path (Split-Path $PSScriptRoot -Parent) "scrcpy-win64-v5.0.1\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }

if (-not $Pkg) { Write-Host "用法: open-app.ps1 <包名> [-Windowed]"; exit 1 }

# 找虚拟屏（displayId 最大且不为 0）
$idsLine = (& $adb -d shell "dumpsys display | grep -o -E 'displayId [0-9]+'" 2>&1) -join " "
$nums = [regex]::Matches($idsLine, 'displayId (\d+)') | ForEach-Object { [int]$_.Groups[1].Value }
$vd = ($nums | Where-Object { $_ -ne 0 } | Sort-Object | Select-Object -Last 1)
if (-not $vd) {
    Write-Host "[!] 没有虚拟屏。先跑 2-start-pc.bat"
    exit 1
}

# 包名 -> 启动组件
$cmp = $Pkg
if ($Pkg -notmatch '/') {
    $resolved = (& $adb -d shell "cmd package resolve-activity --brief -c android.intent.category.LAUNCHER $Pkg" 2>&1) -join "`n"
    $line = ($resolved -split "`n" | Where-Object { $_ -match '/' } | Select-Object -Last 1)
    if ($line) { $cmp = $line.Trim() }
}
if ($cmp -notmatch '/') { Write-Host "[!] 找不到 $Pkg 的启动界面"; exit 1 }

$mode = if ($Windowed) { 5 } else { 1 }   # 1=fullscreen, 5=freeform
& $adb -d shell "am start --display $vd --windowingMode $mode -n $cmp" 2>&1 | Out-Null

$label = if ($Windowed) { "小窗" } else { "全屏" }
Write-Host ("已在 display {0} 上以{1}方式打开 {2}" -f $vd, $label, $Pkg)
