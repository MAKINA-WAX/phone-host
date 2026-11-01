# 启动时恢复上次使用的模式（供 启动.bat 调用）
# 规则：设备在 + 没有投屏 + 没有暂停标记 → 按 last-mode.txt 启动
$ErrorActionPreference = "Continue"
$root = $PSScriptRoot
$localTemp = Join-Path $root "tmp"
if (-not (Test-Path $localTemp)) { New-Item -ItemType Directory -Path $localTemp -Force | Out-Null }
$env:TEMP = $localTemp
$env:TMP = $localTemp

$adb = Join-Path (Split-Path $root -Parent) "scrcpy-win64-v5.0.1\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }

Start-Sleep -Seconds 6   # 等守护/托盘先起来

if (Test-Path (Join-Path $root "paused.flag")) { Write-Host "[恢复] 有暂停标记，跳过"; exit 0 }
if (Get-Process scrcpy -ErrorAction SilentlyContinue) { Write-Host "[恢复] 已经有投屏，跳过"; exit 0 }

$o = ((& $adb devices 2>&1) -join "`n")
if ($o -notmatch "(?m)^\S+\s+device\s*$") { Write-Host "[恢复] 设备未连接，跳过"; exit 0 }

$mode = "desktop-lxqt"
$mf = Join-Path $root "last-mode.txt"
if (Test-Path $mf) {
    $m = (Get-Content $mf -Raw -ErrorAction SilentlyContinue).Trim()
    if ($m) { $mode = $m }
}
Write-Host "[恢复] 上次模式: $mode"

# 桌面类模式需要虚拟屏，没有就先建一块
if ($mode -like 'desktop*' -or $mode -eq 'game-vd') {
    $vdLine = ((& $adb -d shell "dumpsys display | grep -o -E 'displayId [0-9]+'" 2>&1) -join " ")
    $nums = [regex]::Matches($vdLine, 'displayId (\d+)') | ForEach-Object { [int]$_.Groups[1].Value } | Where-Object { $_ -ne 0 }
    if (-not $nums) {
        Write-Host "[恢复] 没有虚拟屏 -> 先开画布"
        & powershell -NoProfile -ExecutionPolicy Bypass -File "$root\auto-start.ps1" | Out-Null
        Start-Sleep -Seconds 12
    }
}

switch ($mode) {
    "desktop-lxqt" { Start-Process powershell -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","$root\start-lxqt.ps1" -WindowStyle Hidden }
    "desktop"      { Start-Process powershell -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","$root\start-xfce.ps1" -WindowStyle Hidden }
    "mirror-full"  { Start-Process powershell -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","$root\mirror-phone.ps1","-Mode","full","-Mouse","sdk" -WindowStyle Hidden }
    "mirror-window"{ Start-Process powershell -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","$root\mirror-phone.ps1","-Mode","window","-Mouse","sdk" -WindowStyle Hidden }
    "game-vd"      { Start-Process powershell -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","$root\game-vd.ps1" -WindowStyle Hidden }
    default        { Write-Host "[恢复] 未知模式 $mode，跳过" }
}
Add-Content -Path (Join-Path $root "reconnect.log") -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [启动恢复] $mode" -Encoding UTF8
