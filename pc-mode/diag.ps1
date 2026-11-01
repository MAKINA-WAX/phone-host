# 诊断 / 调试：收集投屏链路关键状态，生成报告文件（并可用记事本打开）
param([switch]$NoOpen)
$ErrorActionPreference = "Continue"
$root = $PSScriptRoot
$localTemp = Join-Path $root "tmp"
if (-not (Test-Path $localTemp)) { New-Item -ItemType Directory -Path $localTemp -Force | Out-Null }
$env:TEMP = $localTemp
$env:TMP = $localTemp

$adb = Join-Path (Split-Path $root -Parent) "scrcpy-win64-v5.0.1\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }

Add-Type -AssemblyName System.Drawing
if (-not ([System.Management.Automation.PSTypeName]'DbgR.W').Type) {
    Add-Type -Name W -Namespace DbgR -MemberDefinition '[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r); [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v); [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }'
}
[void][DbgR.W]::SetProcessDpiAwarenessContext([IntPtr](-4))

$lines = New-Object System.Collections.Generic.List[string]
function Add-L([string]$s) { $lines.Add($s) }
function Add-Section([string]$t) { Add-L ""; Add-L ("=== " + $t + " ===") }

Add-L "手机主机 · 诊断报告"
Add-L ("时间: " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
Add-L ("电脑: " + $env:COMPUTERNAME + "  用户: " + $env:USERNAME)

Add-Section "adb 设备"
try { Add-L (((& $adb devices -l 2>&1) -join "`n").Trim()) } catch { Add-L ("adb 调用失败: " + $_.Exception.Message) }
$present = $false
try { $present = (((& $adb devices 2>&1) -join "`n") -match "(?m)^\S+\s+device\s*$") } catch {}
Add-L ("设备是否可用: " + $present)

if ($present) {
    Add-Section "手机信息"
    $pairs = @(
        @("USB 模式", "getprop sys.usb.config"),
        @("型号", "getprop ro.product.model"),
        @("系统版本", "getprop ro.build.version.release")
    )
    foreach ($kv in $pairs) {
        try { Add-L ($kv[0] + ": " + (((& $adb -d shell $kv[1] 2>&1) -join "").Trim())) } catch {}
    }
    try {
        $d = ((& $adb -d shell "dumpsys display | grep -o -E 'displayId [0-9]+'" 2>&1) -join " ")
        $nums = ([regex]::Matches($d, 'displayId (\d+)') | ForEach-Object { [int]$_.Groups[1].Value } | Sort-Object -Unique) -join ", "
        Add-L ("display 列表: " + $nums)
    } catch {}
    try { Add-L ("前台 Activity: " + (((& $adb -d shell "dumpsys activity activities | grep -m1 topResumedActivity" 2>&1) -join "").Trim())) } catch {}
    try {
        $x = ((& $adb -d shell "ps -A -o PID,ETIME,NAME | grep -E 'xfce4-session|termux-x11'" 2>&1) -join "`n").Trim()
        if ($x) {
            Add-L "Linux 桌面进程:"
            $x -split "`n" | ForEach-Object { Add-L ("  " + $_.Trim()) }
        } else { Add-L "Linux 桌面进程: 未运行" }
    } catch {}
    try {
        $req = ((& $adb -d shell "run-as com.termux cat files/home/.pc-display-request 2>/dev/null" 2>&1) -join "").Trim()
        Add-L ("待处理的手机请求: " + $(if ($req) { $req } else { "无" }))
    } catch {}
}

Add-Section "PC 侧进程"
$sc = Get-Process scrcpy -ErrorAction SilentlyContinue | Select-Object -First 1
if ($sc) {
    Add-L ("scrcpy: pid " + $sc.Id + "  启动于 " + $sc.StartTime.ToString('HH:mm:ss') + "  内存 " + [math]::Round($sc.WorkingSet64/1MB,0) + " MB")
    try {
        $r = New-Object DbgR.W+RECT
        if ([DbgR.W]::GetWindowRect($sc.MainWindowHandle, [ref]$r)) {
            $w = $r.Right - $r.Left; $h = $r.Bottom - $r.Top
            Add-L ("投屏窗口: " + $w + "x" + $h + " @ (" + $r.Left + "," + $r.Top + ")")
            if ($w -gt 50 -and $h -gt 50) {
                $sw = [int]($w * 0.3); $sh = [int]($h * 0.3)
                if ($sw -lt 1) { $sw = 1 }
                if ($sh -lt 1) { $sh = 1 }
                $bmp = New-Object System.Drawing.Bitmap $sw, $sh
                $g = [System.Drawing.Graphics]::FromImage($bmp)
                $g.CopyFromScreen(($r.Left + [int](($w-$sw)/2)), ($r.Top + [int](($h-$sh)/2)), 0, 0, (New-Object System.Drawing.Size $sw, $sh))
                $g.Dispose()
                $sum = 0.0; $n = 0
                for ($x = 0; $x -lt $sw; $x += 7) {
                    for ($y = 0; $y -lt $sh; $y += 7) {
                        $c = $bmp.GetPixel($x, $y)
                        $sum += (0.299*$c.R + 0.587*$c.G + 0.114*$c.B); $n++
                    }
                }
                $bmp.Dispose()
                $avg = if ($n -gt 0) { [int]($sum / $n) } else { -1 }
                Add-L ("窗口中心平均亮度: " + $avg + $(if ($avg -ge 0 -and $avg -lt 10) { "   <== 判定为黑屏" } else { "" }))
            }
        }
    } catch { Add-L ("窗口采样失败: " + $_.Exception.Message) }
} else {
    Add-L "scrcpy: 未运行"
}

$wp = (Get-Content (Join-Path $localTemp "watch-reconnect.pid") -Raw -ErrorAction SilentlyContinue)
if ($wp) {
    $wp = $wp.Trim()
    $alive = if ($wp -match '^\d+$') { [bool](Get-Process -Id ([int]$wp) -ErrorAction SilentlyContinue) } else { $false }
    $beat = (Get-Content (Join-Path $localTemp "watch.heartbeat") -Raw -ErrorAction SilentlyContinue)
    Add-L ("守护: pid " + $wp + "  存活=" + $alive + "  心跳=" + $(if ($beat) { $beat.Trim() } else { "无" }))
}
$tpid = (Get-Content (Join-Path $localTemp "tray.pid") -Raw -ErrorAction SilentlyContinue)
if ($tpid) { Add-L ("托盘: pid " + $tpid.Trim()) }

Add-Section "配置与状态"
$mode = (Get-Content (Join-Path $root "last-mode.txt") -Raw -ErrorAction SilentlyContinue)
Add-L ("last-mode: " + $(if ($mode) { $mode.Trim() } else { "无" }))
$paused = Test-Path (Join-Path $root "paused.flag")
$pInfo = ""
if ($paused) { $pInfo = "  内容: " + ((Get-Content (Join-Path $root "paused.flag") -Raw -ErrorAction SilentlyContinue) -replace "\s","") }
Add-L ("paused.flag: " + $paused + $pInfo)
$vd = (Get-Content (Join-Path $localTemp "vd-id.txt") -Raw -ErrorAction SilentlyContinue)
Add-L ("记录的虚拟屏 id: " + $(if ($vd) { $vd.Trim() } else { "无" }))

Add-Section "reconnect.log 最后 25 行"
$lg = Join-Path $root "reconnect.log"
if (Test-Path $lg) {
    (Get-Content $lg -Encoding UTF8 -ErrorAction SilentlyContinue | Select-Object -Last 25) | ForEach-Object { Add-L $_ }
} else { Add-L "（没有日志）" }

$out = $lines -join "`r`n"
$dir = Join-Path $root "debug"
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$file = Join-Path $dir ("debug-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".txt")
[System.IO.File]::WriteAllText($file, $out, (New-Object System.Text.UTF8Encoding($true)))

Write-Host $out
Write-Host ""
Write-Host ("报告已保存: " + $file)
if (-not $NoOpen) { Start-Process notepad.exe -ArgumentList "`"$file`"" }
