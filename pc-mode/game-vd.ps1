# 防烧屏游戏模式：把游戏放到【虚拟屏】上跑，物理屏幕真正熄掉（零发光）
# 原理：scrcpy 用 --new-display 建一块独立屏幕，游戏渲染在那块屏上；
#       物理面板用 KEYCODE_SLEEP 真正断电（DOZE），虚拟屏不受影响 → 投屏照常。
# 用法: game-vd.ps1 [-Package com.kurogame.mingchao] [-W 2400] [-H 1080] [-Dpi 420] [-BitRate 60M] [-Fps 60]
param(
    [string]$Package = "com.kurogame.mingchao",
    [int]$W = 2400,
    [int]$H = 1080,
    [int]$Dpi = 420,
    [string]$BitRate = "60M",
    [string]$Fps = "60"
)
$ErrorActionPreference = "Continue"
$localTemp = Join-Path $PSScriptRoot "tmp"
if (-not (Test-Path $localTemp)) { New-Item -ItemType Directory -Path $localTemp -Force | Out-Null }
$env:TEMP = $localTemp
$env:TMP = $localTemp

$adb = Join-Path (Split-Path $PSScriptRoot -Parent) "scrcpy-win64-v5.0.1\adb.exe"
$scrcpy = Join-Path (Split-Path $PSScriptRoot -Parent) "scrcpy-win64-v5.0.1\scrcpy.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }
if (-not (Test-Path $scrcpy)) { $scrcpy = "scrcpy" }

$dev = ((& $adb devices 2>&1) -join "`n")
if ($dev -notmatch "device\r?\n" -and $dev -notmatch "device$") { Write-Host "[!] 没检测到手机"; exit 1 }

# 先唤醒并确保解锁
& $adb -d shell "input keyevent 224" 2>&1 | Out-Null
Start-Sleep -Milliseconds 800

Get-Process scrcpy -ErrorAction SilentlyContinue | Stop-Process -Force
& $adb -d shell "pkill -f com.genymobile.scrcpy" 2>&1 | Out-Null
Start-Sleep -Seconds 2

# 先把已经在主屏跑的游戏停掉，否则 --start-app 只会把旧任务拉到主屏
Remove-Item (Join-Path $PSScriptRoot "paused.flag") -ErrorAction SilentlyContinue
Set-Content -Path (Join-Path $PSScriptRoot "last-mode.txt") -Value "game-vd" -Encoding ASCII
Write-Host "[0/3] 先 force-stop $Package（否则它会被拉到主屏）"
& $adb -d shell "am force-stop $Package" 2>&1 | Out-Null
Start-Sleep -Seconds 2

# 窗口按虚拟屏比例算高度，避免垂直黑边
$winW = 2880
$winH = [int]($winW * $H / $W)
Write-Host "[1/3] 建虚拟屏 ${W}x${H}/${Dpi}dpi，把 $Package 开在上面（窗口 ${winW}x${winH}）"
$xArgs = @(
    "-d",
    "--new-display=${W}x${H}/$Dpi",
    "--start-app=$Package",
    "--window-borderless", "--window-x", "0", "--window-y", "0",
    "--window-width", "$winW", "--window-height", "$winH",
    "--max-fps", "$Fps", "--video-bit-rate", "$BitRate",
    "--keyboard=sdk", "--mouse=sdk", "--gamepad=uhid", "--stay-awake",
    "--window-title", "游戏（虚拟屏 · 防烧屏）"
)
Write-Host ("      scrcpy " + ($xArgs -join " "))
Start-Process -FilePath $scrcpy -ArgumentList $xArgs -WindowStyle Hidden

Write-Host "[2/3] 等 25 秒让游戏加载，然后把物理屏幕真正熄掉（防烧屏）"
Start-Sleep -Seconds 25
& $adb -d shell "input keyevent 223" 2>&1 | Out-Null
Start-Sleep -Seconds 2
$st = ((& $adb -d shell "dumpsys display | grep -m1 mScreenState" 2>&1) -join "").Trim()
$wk = ((& $adb -d shell "dumpsys power | grep -m1 mWakefulness=" 2>&1) -join "").Trim()
Write-Host "      物理屏状态: $st / $wk  （DOZE = 已熄灭）"

Write-Host "[3/3] 监视投屏：窗口关闭后自动唤醒屏幕"
$wake = @"
`$ErrorActionPreference = 'SilentlyContinue'
while ((Get-Process scrcpy).Count -gt 0) { Start-Sleep -Seconds 2 }
& '$adb' -d shell "input keyevent 224" | Out-Null
"@
Set-Content -Path (Join-Path $PSScriptRoot "tmp\wake-after-vd.ps1") -Value $wake -Encoding UTF8
Start-Process -FilePath "powershell" -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-WindowStyle","Hidden","-File","$(Join-Path $PSScriptRoot 'tmp\wake-after-vd.ps1')" -WindowStyle Hidden

Write-Host ""
Write-Host "完成：游戏在虚拟屏上跑，物理屏已熄灭（零发光，不会烧屏）。"
Write-Host "  Alt+Q 退出投屏，退出后会自动唤醒手机屏幕。"
