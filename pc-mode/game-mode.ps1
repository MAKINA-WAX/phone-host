# 游戏模式：手机看起来熄屏（亮度 0，OLED 等于黑）+ 手柄直通 + 全屏投屏
# 用亮度 0 而不是 --turn-screen-off：本机 MIUI 会忽略 scrcpy 的熄屏调用，
# 而真正 SLEEP 会让游戏 onPause；亮度 0 时屏幕仍在渲染，游戏不暂停。
param(
    [string]$BitRate = "60M",
    [string]$Fps = "60"
)
$ErrorActionPreference = "Continue"
$localTemp = Join-Path $PSScriptRoot "tmp"
if (-not (Test-Path $localTemp)) { New-Item -ItemType Directory -Path $localTemp -Force | Out-Null }
$env:TEMP = $localTemp
$env:TMP = $localTemp

$adb = Join-Path (Split-Path $PSScriptRoot -Parent) "scrcpy-win64-v5.0.1\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }

$bak = Join-Path $PSScriptRoot "brightness.bak"
$cur = ((& $adb -d shell "settings get system screen_brightness" 2>&1) -join "").Trim()
$mode = ((& $adb -d shell "settings get system screen_brightness_mode" 2>&1) -join "").Trim()
if ($cur -match '^\d+$') {
    Set-Content -Path $bak -Value "$cur|$mode" -Encoding ASCII
    Remove-Item (Join-Path $PSScriptRoot "paused.flag") -ErrorAction SilentlyContinue
Set-Content -Path (Join-Path $PSScriptRoot "last-mode.txt") -Value "game-brightness" -Encoding ASCII
Write-Host "[1/3] 记录原亮度 $cur / 自动亮度模式 $mode，把屏幕设为全黑"
    & $adb -d shell "settings put system screen_brightness_mode 0" 2>&1 | Out-Null
    & $adb -d shell "settings put system screen_brightness 0" 2>&1 | Out-Null
} else {
    Write-Host "[1/3] 读取亮度失败：$cur（跳过调暗）"
}

Write-Host "[2/3] 启动全屏投屏 + 手柄直通（手柄需插在电脑上）…"
& powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\mirror-phone.ps1" -Mode full -Mouse sdk -BitRate $BitRate -Fps $Fps -ExtraArgs "--stay-awake --gamepad=uhid"

Write-Host "[3/3] 监视投屏进程：窗口关闭后自动恢复亮度"
$restore = @"
`$ErrorActionPreference = 'SilentlyContinue'
while ((Get-Process scrcpy).Count -gt 0) { Start-Sleep -Seconds 2 }
`$b = Get-Content '$bak' -ErrorAction SilentlyContinue
if (`$b -match '^(\d+)\|(\d+)?') {
    `$v = `$Matches[1]; `$m = if (`$Matches[2]) { `$Matches[2] } else { '0' }
    & '$adb' -d shell "settings put system screen_brightness_mode `$m" | Out-Null
    if (`$m -eq '0') { & '$adb' -d shell "settings put system screen_brightness `$v" | Out-Null }
}
"@
Set-Content -Path (Join-Path $PSScriptRoot "tmp\restore-brightness.ps1") -Value $restore -Encoding UTF8
Start-Process -FilePath "powershell" -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-WindowStyle","Hidden","-File","$(Join-Path $PSScriptRoot 'tmp\restore-brightness.ps1')" -WindowStyle Hidden

Write-Host "完成：手机变成黑屏但游戏继续跑；Alt+O 可开关手机屏，Alt+Q 退出（退出后自动恢复亮度）"
