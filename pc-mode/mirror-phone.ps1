# 直接镜像手机本机屏幕（不开虚拟屏）：自动按显示器物理分辨率铺满
# 用法: mirror-phone.ps1 [-BitRate 40M] [-Fps 60]
param(
    [string]$BitRate = "40M",
    [string]$Fps = "60",
    [string]$Mouse = "uhid",
    # full = 无边框全屏（视频等比缩放居中）；window = 带标题栏，可拖动/缩放
    [string]$Mode = "full",
    # 追加任意 scrcpy 参数（空格分隔），例如 "--turn-screen-off --gamepad=uhid"
    [string]$ExtraArgs = ""
)

$ErrorActionPreference = "Continue"
# 记录上次使用的模式，供 watch-reconnect.ps1 重连时使用
$localTemp = Join-Path $PSScriptRoot "tmp"
if (-not (Test-Path $localTemp)) { New-Item -ItemType Directory -Path $localTemp -Force | Out-Null }
$env:TEMP = $localTemp
$env:TMP = $localTemp

Add-Type -Name Mon -Namespace Mirror -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
public delegate bool EnumProc(IntPtr h, IntPtr hdc, IntPtr r, IntPtr d);
[DllImport("user32.dll")] public static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr r, EnumProc p, IntPtr d);
[DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern bool GetMonitorInfo(IntPtr h, ref MI i);
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int l, t, r, b; }
[StructLayout(LayoutKind.Sequential)] public struct MI { public int cb; public RECT mon; public RECT work; public uint flags; }
'@
[void][Mirror.Mon]::SetProcessDpiAwarenessContext([IntPtr](-4))

$mons = New-Object System.Collections.ArrayList
$cb = [Mirror.Mon+EnumProc]{
    param($h, $hdc, $r, $d)
    $mi = New-Object Mirror.Mon+MI
    $mi.cb = [System.Runtime.InteropServices.Marshal]::SizeOf($mi)
    if ([Mirror.Mon]::GetMonitorInfo($h, [ref]$mi)) {
        [void]$mons.Add([pscustomobject]@{
            L = $mi.mon.l; T = $mi.mon.t
            W = $mi.mon.r - $mi.mon.l; H = $mi.mon.b - $mi.mon.t
            Primary = (($mi.flags -band 1) -ne 0)
        })
    }
    return $true
}
[void][Mirror.Mon]::EnumDisplayMonitors([IntPtr]::Zero, [IntPtr]::Zero, $cb, [IntPtr]::Zero)

$m = $mons | Where-Object { $_.Primary } | Select-Object -First 1
if (-not $m) { $m = $mons[0] }
if (-not $m) { Write-Host "[!] 没读到显示器"; exit 1 }

$adb = Join-Path (Split-Path $PSScriptRoot -Parent) "scrcpy-win64-v5.0.1\adb.exe"
$scrcpy = Join-Path (Split-Path $PSScriptRoot -Parent) "scrcpy-win64-v5.0.1\scrcpy.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }
if (-not (Test-Path $scrcpy)) { $scrcpy = "scrcpy" }

Get-Process scrcpy -ErrorAction SilentlyContinue | Stop-Process -Force
& $adb -d shell "pkill -f com.genymobile.scrcpy" 2>&1 | Out-Null
Start-Sleep -Seconds 2

# 手机是竖屏，按高度适配并水平居中（否则会贴在屏幕最左边）
$ph = ((& $adb -d shell "wm size" 2>&1) -join "").Trim()
$pw = 0; $phh = 0
if ($ph -match "(\d+)x(\d+)") {
    $a = [int]$Matches[1]; $b = [int]$Matches[2]
    # 取较短边为宽
    if ($a -lt $b) { $pw = $a; $phh = $b } else { $pw = $b; $phh = $a }
}
# 按“当前屏幕方向”算宽高比（手机会旋转，wm size 永远是竖的基准）
$rot = 0
$rline = ((& $adb -d shell "dumpsys display | grep -m1 -o 'mRotation=[0-9]'" 2>&1) -join "")
if ($rline -match "mRotation=(\d)") { $rot = [int]$Matches[1] }
$landscape = ($rot -eq 1 -or $rot -eq 3)
$ratio = 9.0 / 20.0
if ($pw -gt 0 -and $phh -gt 0) { $ratio = if ($landscape) { $phh / $pw } else { $pw / $phh } }

Remove-Item (Join-Path $PSScriptRoot "paused.flag") -ErrorAction SilentlyContinue
Set-Content -Path (Join-Path $PSScriptRoot "last-mode.txt") -Value ("mirror-" + $(if ($Mode -eq "window") { "window" } else { "full" })) -Encoding ASCII
$xArgs = @("-d")
if ($Mode -eq "window") {
    # 普通窗口：有标题栏，鼠标可拖动、可拉边缘缩放
    $winH = [int]($m.H * 0.74)
    $winW = [int]($winH * $ratio)
    $winX = $m.L + [int](($m.W - $winW) / 2)
    $winY = $m.T + [int](($m.H - $winH) / 2)
    $xArgs += @("--window-x", "$winX", "--window-y", "$winY",
                "--window-width", "$winW", "--window-height", "$winH",
                "--window-title", "手机镜像")
    Write-Host "[镜像-窗口] 手机 $pw x $phh -> ${winW}x${winH} @ ($winX,$winY)  码率 $BitRate 帧率 $Fps  鼠标 $Mouse"
} else {
    # 全屏：窗口铺满整块显示器，视频等比缩放居中（不裁切，多余部分留黑边）
    $winW = $m.W; $winH = $m.H
    $xArgs += @("--window-borderless", "--window-x", "$($m.L)", "--window-y", "$($m.T)",
                "--window-width", "$winW", "--window-height", "$winH",
                "--window-title", "手机镜像")
    Write-Host "[镜像-全屏] 屏幕 $($m.W)x$($m.H)  视频 $pw x $phh 等比缩放居中  码率 $BitRate 帧率 $Fps  鼠标 $Mouse"
}
$xArgs += @("--max-fps", "$Fps", "--video-bit-rate", "$BitRate",
            "--keyboard=$(if ($Mouse -eq "sdk") { "sdk" } else { "uhid" })", "--mouse=$Mouse")
if ($ExtraArgs -and $ExtraArgs.Trim()) { $xArgs += ($ExtraArgs.Trim() -split "\s+") }
Write-Host ("[scrcpy] " + ($xArgs -join " "))
Start-Process -FilePath $scrcpy -ArgumentList $xArgs -WindowStyle Hidden

Start-Sleep -Seconds 9
$focus = Join-Path $PSScriptRoot "focus-scrcpy.ps1"
if (Test-Path $focus) { & powershell -NoProfile -ExecutionPolicy Bypass -File $focus | Out-Null }
Write-Host "完成"
