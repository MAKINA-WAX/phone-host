# 投屏守护（简单粗暴版）
# 逻辑：每 4 秒看一次——手机在、投屏不在 → 立刻开；开了没起来 → 重试；拔线 → 把僵死的投屏杀掉
# 不依赖"状态跳变"，所以反复拔插也稳
param([int]$IntervalSec = 4)
$ErrorActionPreference = "Continue"
$root = $PSScriptRoot
$localTemp = Join-Path $root "tmp"
if (-not (Test-Path $localTemp)) { New-Item -ItemType Directory -Path $localTemp -Force | Out-Null }
$env:TEMP = $localTemp
$env:TMP = $localTemp

$adb = Join-Path (Split-Path $root -Parent) "scrcpy-win64-v5.0.1\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }
$logFile   = Join-Path $root "reconnect.log"
$modeFile  = Join-Path $root "last-mode.txt"
$pauseFlag = Join-Path $root "paused.flag"
$pidFile   = Join-Path $localTemp "watch-reconnect.pid"
$beatFile  = Join-Path $localTemp "watch.heartbeat"

if (Test-Path $pidFile) {
    $old = (Get-Content $pidFile -Raw -ErrorAction SilentlyContinue).Trim()
    if ($old -match '^\d+$' -and (Get-Process -Id ([int]$old) -ErrorAction SilentlyContinue)) {
        Write-Host "已有守护在运行 (pid $old)"; exit 0
    }
}
Set-Content -Path $pidFile -Value $PID -Encoding ASCII

function Log([string]$m) {
    Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m" -Encoding UTF8
}
function Adb-Device {
    try {
        $o = (& $adb devices 2>&1) -join "`n"
        return ($o -match "(?m)^\S+\s+device\s*$")
    } catch { return $false }
}
function Last-Mode {
    if (Test-Path $modeFile) {
        $m = (Get-Content $modeFile -Raw -ErrorAction SilentlyContinue).Trim()
        if ($m) { return $m }
    }
    return "mirror-full"
}
function Launch([string]$mode) {
    switch ($mode) {
        "game-vd"         { Start-Process powershell -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","$root\game-vd.ps1" -WindowStyle Hidden }
        "game-brightness" { Start-Process powershell -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","$root\game-mode.ps1" -WindowStyle Hidden }
        "mirror-window"   { Start-Process powershell -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","$root\mirror-phone.ps1","-Mode","window","-Mouse","sdk" -WindowStyle Hidden }
        "mirror-full"     { Start-Process powershell -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","$root\mirror-phone.ps1","-Mode","full","-Mouse","sdk" -WindowStyle Hidden }
        "desktop"         { Start-Process powershell -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","$root\start-xfce.ps1" -WindowStyle Hidden }
        "desktop-lxqt"    { Start-Process powershell -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","$root\start-lxqt.ps1" -WindowStyle Hidden }
        default           { Start-Process powershell -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","$root\mirror-phone.ps1","-Mode","full","-Mouse","sdk" -WindowStyle Hidden }
    }
}
function Focus-Mirror {
    $f = Join-Path $root "focus-scrcpy.ps1"
    if (Test-Path $f) { & powershell -NoProfile -ExecutionPolicy Bypass -File $f | Out-Null }
}
function Get-MirrorBlack {
    # 采样投屏窗口中心区域的平均亮度；全黑返回 $true
    try {
        $proc = Get-Process scrcpy -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
        if (-not $proc) { return $false }
        if (-not ([System.Management.Automation.PSTypeName]'Wh.Black').Type) {
            Add-Type -Name Black -Namespace Wh -MemberDefinition '[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r); [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v); [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }'
        }
        if (-not ([System.Management.Automation.PSTypeName]'System.Drawing.Bitmap').Type) { Add-Type -AssemblyName System.Drawing }
        [void][Wh.Black]::SetProcessDpiAwarenessContext([IntPtr](-4))
        $r = New-Object Wh.Black+RECT
        if (-not [Wh.Black]::GetWindowRect($proc.MainWindowHandle, [ref]$r)) { return $false }
        $w = $r.Right - $r.Left; $h = $r.Bottom - $r.Top
        if ($w -lt 50 -or $h -lt 50) { return $false }
        $sw = [int]($w * 0.30); $sh = [int]($h * 0.30)
        $sx = $r.Left + [int](($w - $sw) / 2); $sy = $r.Top + [int](($h - $sh) / 2)
        $bmp = New-Object System.Drawing.Bitmap $sw, $sh
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.CopyFromScreen($sx, $sy, 0, 0, (New-Object System.Drawing.Size $sw, $sh))
        $g.Dispose()
        $sum = 0.0; $n = 0
        $stepX = [Math]::Max(1, [int]($sw / 20)); $stepY = [Math]::Max(1, [int]($sh / 20))
        for ($x = 0; $x -lt $sw; $x += $stepX) {
            for ($y = 0; $y -lt $sh; $y += $stepY) {
                $c = $bmp.GetPixel($x, $y)
                $sum += (0.299 * $c.R + 0.587 * $c.G + 0.114 * $c.B); $n++
            }
        }
        $bmp.Dispose()
        if ($n -eq 0) { return $false }
        $avg = $sum / $n
        $script:lastLuma = [int]$avg
        return ($avg -lt 10)
    } catch { return $false }
}

function Start-Mirror([string]$mode) {
    for ($try = 1; $try -le 3; $try++) {
        Log "-> 第 $try 次尝试启动投屏（模式: $mode）"
        Get-Process scrcpy -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        & $adb -d shell "pkill -f com.genymobile.scrcpy" 2>&1 | Out-Null
        Start-Sleep -Milliseconds 800
        Launch $mode
        $ok = $false
        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep -Seconds 1
            if (Get-Process scrcpy -ErrorAction SilentlyContinue) { $ok = $true; break }
        }
        if ($ok) {
            Start-Sleep -Seconds 2
            Focus-Mirror
            Log "投屏已启动（第 $try 次成功）"
            return $true
        }
        Log "第 $try 次没起来，重试"
    }
    Log "连续 3 次都没起来，等下一轮"
    return $false
}

Log "守护启动（简单版） pid=$PID 间隔=${IntervalSec}s"
$lastKill = [datetime]::MinValue
$weStarted = $null
$wasPresent = Adb-Device
$script:blackHits = 0
$script:lastRecover = [datetime]::MinValue
$script:lastLuma = -1
$hadScrcpy = [bool](Get-Process scrcpy -ErrorAction SilentlyContinue)
while ($true) {
    try {
        Set-Content -Path $beatFile -Value (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -Encoding ASCII

        # 检查手机启动器发来的"投屏请求"
        $pausedNow = Test-Path $pauseFlag
        try {
            $req = ((& $adb -d shell "run-as com.termux cat files/home/.pc-display-request 2>/dev/null" 2>&1) -join "").Trim()
            if ($req -match '^(canvas|mirror|desktop)' -and -not $pausedNow) {
                Log "收到手机请求: $req"
                & $adb -d shell "run-as com.termux rm -f files/home/.pc-display-request" 2>&1 | Out-Null
                if ($req -eq 'canvas') {
                    Start-Process powershell -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","$root\auto-start.ps1" -WindowStyle Hidden
                    Log "已按请求创建虚拟屏（画布）"
                } elseif ($req -eq 'mirror') {
                    Start-Process powershell -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","$root\mirror-phone.ps1","-Mode","full","-Mouse","sdk" -WindowStyle Hidden
                    Log "已按请求启动手机镜像"
                } else {
                    Start-Process powershell -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","$root\desktop-show.ps1" -WindowStyle Hidden
                    Log "已按请求显示 Linux 桌面"
                }
                Start-Sleep -Seconds 15
            }
        } catch {}
        $present = Adb-Device
        $scrcpy  = [bool](Get-Process scrcpy -ErrorAction SilentlyContinue)
        $paused  = Test-Path $pauseFlag

        if (-not $present) {
            if ($scrcpy -and ((Get-Date) - $lastKill).TotalSeconds -gt 30) {
                Get-Process scrcpy -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                Log "设备不在，已结束僵死的投屏进程"
                $lastKill = Get-Date
            }
            $weStarted = $null
        }
        elseif ($wasPresent -eq $false -and $present) {
            # 刚插回来：恢复上次模式
            if (-not $paused) {
                Log "设备重新连接 -> 恢复上次模式"
                [void](Start-Mirror (Last-Mode))
                $weStarted = Get-Date
            } else {
                Log "设备重新连接（守护处于暂停，不自动启动）"
            }
        }
        elseif (-not $scrcpy -and -not $paused) {
            if ($weStarted -and ((Get-Date) - $weStarted).TotalSeconds -lt 180) {
                # 我们刚启动的会话很快就没了 => 崩溃，重试
                Log "投屏进程异常退出 -> 重试"
                [void](Start-Mirror (Last-Mode))
                $weStarted = Get-Date
            } elseif ($hadScrcpy) {
                # 之前确实在跑、现在没了 => 认定用户手动关闭，暂停守护
                Set-Content -Path $pauseFlag -Value "manual-close $(Get-Date -Format 'HH:mm:ss')" -Encoding ASCII
                Log "投屏被手动关闭 -> 守护暂停（恢复：双击 resume.bat，或启动任一投屏模式）"
                $weStarted = $null
            }
        }
        # 黑屏检测（只在桌面/画布模式生效；游戏虚拟屏本身就是黑的，不能误判）
        $modeNow = "mirror-full"
        try { if (Test-Path $modeFile) { $modeNow = (Get-Content $modeFile -Raw).Trim() } } catch {}
        if ($scrcpy -and $modeNow -eq 'desktop') {
            if (Get-MirrorBlack) {
                $script:blackHits++
                Log "检测到投屏黑屏（第 $script:blackHits 次，亮度 $script:lastLuma）"
            } else {
                $script:blackHits = 0
            }
            if ($script:blackHits -ge 3 -and ((Get-Date) - $script:lastRecover).TotalSeconds -gt 90) {
                $script:lastRecover = Get-Date
                $script:blackHits = 0
                # 第一步：只重新吸附显示（不杀进程，桌面上开着的程序都还在）
                Log "连续黑屏 -> 第一步：只重新显示（-Attach，不动桌面进程）"
                & powershell -NoProfile -ExecutionPolicy Bypass -File "$root\start-xfce.ps1" -Attach 2>&1 | Out-Null
                Start-Sleep -Seconds 8
                if (Get-MirrorBlack) {
                    # 第二步：吸附无效（X server 挂了）才重启整个会话
                    Log "重新显示无效 -> 第二步：重启 Linux 桌面会话（会关掉桌面里的程序）"
                    & powershell -NoProfile -ExecutionPolicy Bypass -File "$root\start-xfce.ps1" 2>&1 | Out-Null
                    Start-Sleep -Seconds 20
                } else {
                    Log "重新显示成功，桌面会话没有重启"
                }
            }
        } else {
            $script:blackHits = 0
        }
        $wasPresent = $present
        $hadScrcpy = $scrcpy
    } catch {
        Log "循环异常: $($_.Exception.Message)"
    }
    Start-Sleep -Seconds $IntervalSec
}