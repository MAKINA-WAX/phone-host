# 托盘控制器：常驻通知区域，右键菜单里检测/启动投屏
$ErrorActionPreference = "Continue"
$root = $PSScriptRoot
$localTemp = Join-Path $root "tmp"
if (-not (Test-Path $localTemp)) { New-Item -ItemType Directory -Path $localTemp -Force | Out-Null }
$env:TEMP = $localTemp
$env:TMP = $localTemp

$adb = Join-Path (Split-Path $root -Parent) "scrcpy-win64-v5.0.1\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }

$logPath = Join-Path $localTemp "tray.log"
function TLog([string]$m) { Add-Content -Path $logPath -Value "$(Get-Date -Format 'HH:mm:ss') $m" -Encoding UTF8 }
TLog "script start"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 单实例（pid 文件方式，比 Global 互斥体稳）
$pidFile = Join-Path $localTemp "tray.pid"
if (Test-Path $pidFile) {
    $oldPid = (Get-Content $pidFile -Raw -ErrorAction SilentlyContinue).Trim()
    if ($oldPid -match '^\d+$' -and (Get-Process -Id ([int]$oldPid) -ErrorAction SilentlyContinue)) {
        exit 0
    }
}
Set-Content -Path $pidFile -Value $PID -Encoding ASCII

# ---- 后台探测（adb 查询不放 UI 线程）----
$shared = [hashtable]::Synchronized(@{ ready = $false; ok = $false; serial = ""; model = ""; mirror = $false })
$rs = [runspacefactory]::CreateRunspace()
$rs.Open()
$probe = [powershell]::Create()
$probe.Runspace = $rs
[void]$probe.AddScript({
    param($adbPath, $st)
    while ($true) {
        try {
            $o = ((& $adbPath devices -l 2>&1) -join "`n")
            $m = [regex]::Matches($o, "(?m)^(\S+)\s+device\s*(.*)$")
            if ($m.Count -gt 0) {
                $st.ok = $true
                $st.serial = $m[0].Groups[1].Value
                if ($m[0].Groups[2].Value -match 'model:(\S+)') { $st.model = $Matches[1] }
            } else {
                $st.ok = $false; $st.serial = ""; $st.model = ""
            }
            $st.mirror = [bool](Get-Process scrcpy -ErrorAction SilentlyContinue)
            $st.ready = $true
        } catch {}
        Start-Sleep -Seconds 3
    }
}).AddArgument($adb).AddArgument($shared)
$probeHandle = $probe.BeginInvoke()

function Get-Device {
    return @{ ok = [bool]$shared.ok; serial = [string]$shared.serial; model = [string]$shared.model }
}
function Run([string]$file, [string[]]$extra = @()) {
    $a = @("-NoProfile","-ExecutionPolicy","Bypass","-WindowStyle","Hidden","-File", (Join-Path $root $file)) + $extra
    Start-Process powershell -ArgumentList $a -WindowStyle Hidden
}

function New-TrayIcon {
    $bmp = New-Object System.Drawing.Bitmap 32, 32
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    $body = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 60, 140, 255))
    $g.FillRectangle($body, 9, 4, 14, 24)
    $dark = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 20, 26, 34))
    $g.FillRectangle($dark, 11, 7, 10, 16)
    $g.FillEllipse($dark, 14, 25, 4, 4)
    $body.Dispose(); $dark.Dispose(); $g.Dispose()
    $h = $bmp.GetHicon()
    $ico = [System.Drawing.Icon]::FromHandle($h)
    return $ico
}
$trayIcon = New-TrayIcon
$icon = New-Object System.Windows.Forms.NotifyIcon
$icon.Icon = $trayIcon
$icon.Text = "手机主机 · 控制台"
$icon.Visible = $true
TLog "notifyicon visible"

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$menu.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)

$itStatus = New-Object System.Windows.Forms.ToolStripMenuItem "状态: 检测中…"
$itStatus.Enabled = $false
[void]$menu.Items.Add($itStatus)
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

$itMirrorFull = New-Object System.Windows.Forms.ToolStripMenuItem "手机镜像（全屏）"
$itMirrorFull.add_Click({ Run "mirror-phone.ps1" @("-Mode","full","-Mouse","sdk") })
[void]$menu.Items.Add($itMirrorFull)

$itMirrorWin = New-Object System.Windows.Forms.ToolStripMenuItem "手机镜像（可拖动窗口）"
$itMirrorWin.add_Click({ Run "mirror-phone.ps1" @("-Mode","window","-Mouse","sdk") })
[void]$menu.Items.Add($itMirrorWin)

$itDesktop = New-Object System.Windows.Forms.ToolStripMenuItem "开 Linux 桌面"
$itDesktop.add_Click({ Run "start-xfce.ps1" })
[void]$menu.Items.Add($itDesktop)

$itFix = New-Object System.Windows.Forms.ToolStripMenuItem "修复黑屏（保留桌面程序）"
$itFix.add_Click({ Run "start-xfce.ps1" @("-Attach"); $icon.ShowBalloonTip(3000, "已重新显示", "只是重新铺画面，桌面里的程序不会被关掉", [System.Windows.Forms.ToolTipIcon]::Info) })
[void]$menu.Items.Add($itFix)

$itCanvas = New-Object System.Windows.Forms.ToolStripMenuItem "开画布（虚拟屏）"
$itCanvas.add_Click({ Run "auto-start.ps1" })
[void]$menu.Items.Add($itCanvas)

[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

$itBurn = New-Object System.Windows.Forms.ToolStripMenuItem "防烧屏（熄掉手机面板）"
$itBurn.add_Click({
    Run "anti-burn.ps1" @("-On")
    $icon.ShowBalloonTip(4000, "防烧屏已开启", "面板已断电（零发光）。注意：只对虚拟屏内容有效`n如果你在用手机镜像，画面会一起黑（镜像的就是物理屏）", [System.Windows.Forms.ToolTipIcon]::Info)
})
[void]$menu.Items.Add($itBurn)

$itWake = New-Object System.Windows.Forms.ToolStripMenuItem "唤醒手机屏幕"
$itWake.add_Click({ Run "anti-burn.ps1" @("-Off") })
[void]$menu.Items.Add($itWake)

$itDiag = New-Object System.Windows.Forms.ToolStripMenuItem "调试诊断（生成报告）"
$itDiag.add_Click({ Run "diag.ps1" })
[void]$menu.Items.Add($itDiag)

$itCheck = New-Object System.Windows.Forms.ToolStripMenuItem "检测 USB 投屏设备"
$itCheck.add_Click({
    $d = Get-Device   # 读缓存（3 秒内新鲜）
    if ($d.ok) {
        $extra = ""
        if (Get-Process scrcpy -ErrorAction SilentlyContinue) { $extra = "；投屏进程运行中" } else { $extra = "；投屏未启动" }
        $icon.ShowBalloonTip(4000, "设备已连接", "$($d.model) ($($d.serial))$extra", [System.Windows.Forms.ToolTipIcon]::Info)
    } else {
        $icon.ShowBalloonTip(4000, "未检测到设备", "请检查数据线 / USB 调试授权 / USB 模式是否为「传输文件」", [System.Windows.Forms.ToolTipIcon]::Warning)
    }
})
[void]$menu.Items.Add($itCheck)

$itResume = New-Object System.Windows.Forms.ToolStripMenuItem "恢复自动重连守护"
$itResume.add_Click({
    Remove-Item (Join-Path $root "paused.flag") -ErrorAction SilentlyContinue
    Start-Process powershell -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-WindowStyle","Hidden","-File",(Join-Path $root "watch-reconnect.ps1") -WindowStyle Hidden
    $icon.ShowBalloonTip(3000, "守护已恢复", "插拔会自动重连投屏", [System.Windows.Forms.ToolTipIcon]::Info)
})
[void]$menu.Items.Add($itResume)

$itConsole = New-Object System.Windows.Forms.ToolStripMenuItem "打开控制台"
$itConsole.add_Click({ Start-Process cmd.exe -ArgumentList "/c","启动.bat" -WorkingDirectory $root -WindowStyle Hidden })
[void]$menu.Items.Add($itConsole)

$itStop = New-Object System.Windows.Forms.ToolStripMenuItem "收工（关闭投屏 + 暂停守护）"
$itStop.add_Click({ Start-Process cmd.exe -ArgumentList "/c","stop-pc.bat" -WorkingDirectory $root -WindowStyle Hidden })
[void]$menu.Items.Add($itStop)

[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
$itShutdown = New-Object System.Windows.Forms.ToolStripMenuItem "关闭软件（全部退出）"
$itShutdown.add_Click({
    # 先脱离执行，否则杀托盘时会把当前动作一起中断
    Start-Process powershell -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-WindowStyle","Hidden","-File",(Join-Path $root "shutdown-all.ps1") -WindowStyle Hidden
    $icon.Visible = $false
    [System.Windows.Forms.Application]::Exit()
})
[void]$menu.Items.Add($itShutdown)

$itExit = New-Object System.Windows.Forms.ToolStripMenuItem "退出托盘（保留守护）"
$itExit.add_Click({ $icon.Visible = $false; [System.Windows.Forms.Application]::Exit() })
[void]$menu.Items.Add($itExit)

$icon.ContextMenuStrip = $menu
$icon.add_DoubleClick({ Start-Process cmd.exe -ArgumentList "/c","启动.bat" -WorkingDirectory $root -WindowStyle Hidden })

# 定时刷新状态
$lastOk = $null
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.add_Tick({
    if (-not [bool]$shared.ready) { return }
    $d = Get-Device
    $mirror = [bool]$shared.mirror
    if ($d.ok) {
        $itStatus.Text = "设备: 已连接  " + $(if ($mirror) { "· 投屏中" } else { "· 未投屏" })
        $icon.Text = "手机主机 · 已连接" + $(if ($mirror) { " · 投屏中" } else { "" })
    } else {
        $itStatus.Text = "设备: 未连接"
        $icon.Text = "手机主机 · 未连接"
    }
    if ($script:lastStatusText -ne $itStatus.Text) {
        $script:lastStatusText = $itStatus.Text
        TLog ("status -> " + $itStatus.Text)
    }
    if ($lastOk -ne $null -and $lastOk -ne $d.ok) {
        if ($d.ok) { $icon.ShowBalloonTip(3000, "设备已连接", "可以开始投屏了", [System.Windows.Forms.ToolTipIcon]::Info) }
        else { $icon.ShowBalloonTip(3000, "设备已断开", "等待重新插上（守护会自动重连）", [System.Windows.Forms.ToolTipIcon]::Warning) }
    }
    $lastOk = $d.ok
})
$timer.Start()

# 启动时先显示“检测中”，由后台线程填值
$lastOk = $null

TLog "enter message loop"
try { [System.Windows.Forms.Application]::Run() } catch { TLog ("Run 异常: " + $_.Exception.Message) }
TLog "message loop exited"
$timer.Stop()
$icon.Visible = $false
$icon.Dispose()
