# 自适应投屏：自动读取显示器物理分辨率，按它生成虚拟屏并铺满该显示器
# 用法: auto-start.ps1           用主显示器
#       auto-start.ps1 -Monitor 1   用第 2 块显示器（0 开始）
param([int]$Monitor = 0, [double]$Zoom = 1.0, [int]$ForceW = 0, [int]$ForceH = 0, [int]$ForceDpi = 0)

$ErrorActionPreference = "Continue"

$localTemp = Join-Path $PSScriptRoot "tmp"
if (-not (Test-Path $localTemp)) { New-Item -ItemType Directory -Path $localTemp -Force | Out-Null }
$env:TEMP = $localTemp
$env:TMP = $localTemp

Add-Type -Name Mon -Namespace ScrcpyAuto -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
public delegate bool MonitorEnumProc(IntPtr hMonitor, IntPtr hdc, IntPtr rect, IntPtr data);
[DllImport("user32.dll")] public static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr rect, MonitorEnumProc proc, IntPtr data);
[DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFO info);
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
[StructLayout(LayoutKind.Sequential)] public struct MONITORINFO {
    public int cbSize; public RECT rcMonitor; public RECT rcWork; public uint dwFlags;
}
'@

# 关键：必须 DPI 感知，否则拿到的“分辨率”是缩放后的逻辑值（会把 1/4 屏当成整屏）
[void][ScrcpyAuto.Mon]::SetProcessDpiAwarenessContext([IntPtr](-4))

$mons = New-Object System.Collections.ArrayList
$cb = [ScrcpyAuto.Mon+MonitorEnumProc]{
    param($h, $hdc, $r, $d)
    $mi = New-Object ScrcpyAuto.Mon+MONITORINFO
    $mi.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($mi)
    if ([ScrcpyAuto.Mon]::GetMonitorInfo($h, [ref]$mi)) {
        [void]$mons.Add([pscustomobject]@{
            Left = $mi.rcMonitor.Left; Top = $mi.rcMonitor.Top
            Width = $mi.rcMonitor.Right - $mi.rcMonitor.Left
            Height = $mi.rcMonitor.Bottom - $mi.rcMonitor.Top
            Primary = (($mi.dwFlags -band 1) -ne 0)
        })
    }
    return $true
}
[void][ScrcpyAuto.Mon]::EnumDisplayMonitors([IntPtr]::Zero, [IntPtr]::Zero, $cb, [IntPtr]::Zero)

if ($mons.Count -eq 0) { Write-Host "[!] 没读到显示器"; exit 1 }

# 默认取主屏；-Monitor N 取第 N 块
$m = if ($Monitor -eq 0) { ($mons | Where-Object { $_.Primary } | Select-Object -First 1) } else { $mons[$Monitor] }
if (-not $m) { $m = $mons[0] }

Write-Host "[1/2] 显示器: $($m.Width)x$($m.Height) @ ($($m.Left),$($m.Top))  共 $($mons.Count) 块"
for ($i = 0; $i -lt $mons.Count; $i++) {
    $t = $mons[$i]
    Write-Host ("      [{0}] {1}x{2} @ ({3},{4}){5}" -f $i, $t.Width, $t.Height, $t.Left, $t.Top, ($(if ($t.Primary) { " (主屏)" } else { "" })))
}

# -Zoom：虚拟屏按 1/Zoom 分辨率创建，scrcpy 再放大铺满 → 桌面整体放大，布局不变（不会裁切）
if ($Zoom -le 0) { $Zoom = 1.0 }
$vdW = [int][math]::Round($m.Width / $Zoom)
$vdH = [int][math]::Round($m.Height / $Zoom)
# 默认封顶到 2K 宽，并按显示器比例算高（16:10 屏 → 2560x1600），这样投屏窗口能铺满、没有黑边
if ($ForceW -le 0 -and $vdW -gt 2560) {
    $vdW = 2560
    $vdH = [int][math]::Round($vdW * $m.Height / $m.Width)
}
if ($ForceW -gt 0) { $vdW = $ForceW }
if ($ForceH -gt 0) { $vdH = $ForceH }
# 让 dp 宽度固定在 ~1163（和之前 2880/396 的桌面空间一致）：density = 160 * 宽 / 1163
$density = [int][math]::Round(160.0 * $vdW / 1163.0)
if ($ForceDpi -gt 0) { $density = $ForceDpi }
elseif ($vdW -eq 2560) { $density = 320 }
if ($density -lt 120) { $density = 120 }
if ($density -gt 640) { $density = 640 }
$dpW = [int][math]::Round(160.0 * $vdW / $density)
$dpH = [int][math]::Round(160.0 * $vdH / $density)

Write-Host "[2/2] 虚拟屏 ${vdW}x${vdH}/${density}dpi (缩放 x$Zoom)  (= ${dpW}x${dpH} dp)，窗口铺满该显示器"

$scrcpy = Join-Path (Split-Path $PSScriptRoot -Parent) "scrcpy-win64-v5.0.1\scrcpy.exe"
if (-not (Test-Path $scrcpy)) { $scrcpy = "scrcpy" }

# 先清掉旧进程，避免残留
Get-Process scrcpy -ErrorAction SilentlyContinue | Stop-Process -Force
$adb = Join-Path (Split-Path $PSScriptRoot -Parent) "scrcpy-win64-v5.0.1\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }
& $adb -d shell "pkill -f com.genymobile.scrcpy" 2>&1 | Out-Null
Start-Sleep -Seconds 2

$app = if ($env:PC_START_APP) { $env:PC_START_APP } else { "com.android.chrome" }

$args = @(
    "-d",
    "--new-display=${vdW}x${vdH}/$density",
    "--start-app=$app",
    "--window-borderless",
    "--window-x", "$($m.Left)",
    "--window-y", "$($m.Top)",
    "--window-width", "$($m.Width)",
    "--window-height", "$($m.Height)",
    "--max-fps", "60",
    "--video-bit-rate", "40M",
    "--keyboard=uhid",
    "--mouse=uhid"
)
$beforeIds = @()
try {
    $idsLine0 = (& $adb -d shell "dumpsys display | grep -o -E 'displayId [0-9]+'" 2>&1) -join " "
    $beforeIds = [regex]::Matches($idsLine0, 'displayId (\d+)') | ForEach-Object { [int]$_.Groups[1].Value }
} catch {}
Start-Process -FilePath $scrcpy -ArgumentList $args -WindowStyle Hidden | Out-Null


Start-Sleep -Seconds 10
try {
    $idsLine1 = (& $adb -d shell "dumpsys display | grep -o -E 'displayId [0-9]+'" 2>&1) -join " "
    $afterIds = [regex]::Matches($idsLine1, 'displayId (\d+)') | ForEach-Object { [int]$_.Groups[1].Value }
    $newIds = $afterIds | Where-Object { $_ -ne 0 -and ($beforeIds -notcontains $_) }
    if ($newIds) {
        $vdNew = ($newIds | Sort-Object | Select-Object -Last 1)
        Set-Content -Path (Join-Path $localTemp "vd-id.txt") -Value $vdNew -Encoding ASCII
        Write-Host "      虚拟屏 displayId = $vdNew（已记录到 tmp\vd-id.txt）"
    }
} catch {}
$focus = Join-Path $PSScriptRoot "focus-scrcpy.ps1"
if (Test-Path $focus) { & powershell -NoProfile -ExecutionPolicy Bypass -File $focus | Out-Null }
Write-Host "完成：投屏已铺满显示器 $($m.Width)x$($m.Height)。"
