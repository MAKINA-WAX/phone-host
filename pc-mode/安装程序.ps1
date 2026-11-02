# 手机主机 · 安装程序（图形界面）
# 作用：把电脑端脚本 + scrcpy 装到指定目录；可选通过数据线给手机装 APK；创建快捷方式和计划任务
$ErrorActionPreference = "Continue"
$here = $PSScriptRoot
# 两种布局都能跑：
#   成品包：<包>\安装程序.ps1 + <包>\payload\pc-mode + <包>\payload\scrcpy-win64-v5.0.1
#   项目里：pc-mode\安装程序.ps1 + pc-mode\ + ..\scrcpy-win64-v5.0.1
$payload = Join-Path $here "payload"
$projMode = -not (Test-Path $payload)
if ($projMode) {
    $srcPcDir  = $here
    $srcScrDir = Join-Path (Split-Path $here -Parent) "scrcpy-win64-v5.0.1"
} else {
    $srcPcDir  = Join-Path $payload "pc-mode"
    $srcScrDir = Join-Path $payload "scrcpy-win64-v5.0.1"
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -Name Dp -Namespace Inst -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);'
[void][Inst.Dp]::SetProcessDpiAwarenessContext([IntPtr](-4))

$dpi = 96
try { $g = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero); $dpi = $g.DpiX; $g.Dispose() } catch {}
$s = $dpi / 96.0
function S([double]$v) { [int][math]::Round($v * $s) }

$form = New-Object System.Windows.Forms.Form
$form.Text = "手机主机 · 安装程序"
$form.ClientSize = New-Object System.Drawing.Size((S 620), (S 560))
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 246, 248)
$form.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)

$title = New-Object System.Windows.Forms.Label
$title.Text = "手机主机 · 安装程序"
$title.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 15, [System.Drawing.FontStyle]::Bold)
$title.Location = New-Object System.Drawing.Point((S 22), (S 18))
$title.AutoSize = $true
$form.Controls.Add($title)

$sub = New-Object System.Windows.Forms.Label
$sub.Text = "装电脑端（脚本 + scrcpy + 文档）；手机端装好后在控制台点 ⑦ 一键装"
$sub.ForeColor = [System.Drawing.Color]::FromArgb(110, 110, 118)
$sub.Location = New-Object System.Drawing.Point((S 24), (S 56))
$sub.AutoSize = $true
$form.Controls.Add($sub)

# --- 安装位置 ---
$lblDir = New-Object System.Windows.Forms.Label
$lblDir.Text = "安装到："
$lblDir.Location = New-Object System.Drawing.Point((S 24), (S 92))
$lblDir.AutoSize = $true
$form.Controls.Add($lblDir)

$txtDir = New-Object System.Windows.Forms.TextBox
$txtDir.Text = "C:\PhoneHost"
$txtDir.Location = New-Object System.Drawing.Point((S 88), (S 88))
$txtDir.Size = New-Object System.Drawing.Size((S 400), (S 26))
$form.Controls.Add($txtDir)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "浏览…"
$btnBrowse.Location = New-Object System.Drawing.Point((S 496), (S 87))
$btnBrowse.Size = New-Object System.Drawing.Size((S 96), (S 28))
$form.Controls.Add($btnBrowse)
$btnBrowse.add_Click({
    $fb = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($fb.ShowDialog() -eq "OK") { $txtDir.Text = $fb.SelectedPath }
})

# --- 组件选择 ---
$gb = New-Object System.Windows.Forms.GroupBox
$gb.Text = "安装内容"
$gb.Location = New-Object System.Drawing.Point((S 24), (S 126))
$gb.Size = New-Object System.Drawing.Size((S 568), (S 150))
$form.Controls.Add($gb)

$cbPc = New-Object System.Windows.Forms.CheckBox
$cbPc.Text = "电脑端：脚本 + scrcpy + 文档（约 25 MB）"
$cbPc.Checked = $true
$cbPc.Location = New-Object System.Drawing.Point((S 16), (S 28))
$cbPc.AutoSize = $true
$gb.Controls.Add($cbPc)

$lblPhone = New-Object System.Windows.Forms.Label
$lblPhone.Text = "手机端：装好后打开「手机主机」控制台，点 ⑦ 装手机端（自动装 APK + 环境）"
$lblPhone.ForeColor = [System.Drawing.Color]::FromArgb(110, 110, 118)
$lblPhone.Location = New-Object System.Drawing.Point((S 16), (S 56))
$lblPhone.AutoSize = $true
$gb.Controls.Add($lblPhone)

$cbShortcut = New-Object System.Windows.Forms.CheckBox
$cbShortcut.Text = "在桌面创建快捷方式「手机主机」"
$cbShortcut.Checked = $true
$cbShortcut.Location = New-Object System.Drawing.Point((S 16), (S 84))
$cbShortcut.AutoSize = $true
$gb.Controls.Add($cbShortcut)

$cbTask = New-Object System.Windows.Forms.CheckBox
$cbTask.Text = "注册计划任务（守护进程掉线自动拉起，每 5 分钟检查）"
$cbTask.Checked = $true
$cbTask.Location = New-Object System.Drawing.Point((S 16), (S 112))
$cbTask.AutoSize = $true
$gb.Controls.Add($cbTask)

$cbRun = New-Object System.Windows.Forms.CheckBox
$cbRun.Text = "安装完成后立即启动"
$cbRun.Checked = $false
$cbRun.Location = New-Object System.Drawing.Point((S 24), (S 286))
$cbRun.AutoSize = $true
$form.Controls.Add($cbRun)

# --- 日志 ---
$log = New-Object System.Windows.Forms.TextBox
$log.Multiline = $true
$log.ScrollBars = "Vertical"
$log.ReadOnly = $true
$log.BackColor = [System.Drawing.Color]::FromArgb(24, 26, 30)
$log.ForeColor = [System.Drawing.Color]::FromArgb(220, 220, 225)
$log.Font = New-Object System.Drawing.Font("Consolas", 8.5)
$log.Location = New-Object System.Drawing.Point((S 24), (S 316))
$log.Size = New-Object System.Drawing.Size((S 568), (S 180))
$form.Controls.Add($log)

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Text = "开始安装"
$btnInstall.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 10, [System.Drawing.FontStyle]::Bold)
$btnInstall.Location = New-Object System.Drawing.Point((S 360), (S 508))
$btnInstall.Size = New-Object System.Drawing.Size((S 110), (S 36))
$form.Controls.Add($btnInstall)

$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "退出"
$btnExit.Location = New-Object System.Drawing.Point((S 482), (S 508))
$btnExit.Size = New-Object System.Drawing.Size((S 110), (S 36))
$form.Controls.Add($btnExit)
$btnExit.add_Click({ $form.Close() })

function L([string]$m) {
    $log.AppendText("[" + (Get-Date -Format 'HH:mm:ss') + "] $m`r`n")
    $log.SelectionStart = $log.TextLength
    $log.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

$btnInstall.add_Click({
    $btnInstall.Enabled = $false
    $target = $txtDir.Text.Trim()
    if (-not $target) { L "请先选择安装目录"; $btnInstall.Enabled = $true; return }

    L "=== 开始安装 ==="
    L "目标目录: $target"

    # 1) 建目录
    try {
        if (-not (Test-Path $target)) { New-Item -ItemType Directory -Path $target -Force | Out-Null }
    } catch {
        L "!! 无法创建目录：$($_.Exception.Message)"
        L "   请换个目录（比如 $env:USERPROFILE\PhoneHost）"
        $btnInstall.Enabled = $true
        return
    }

    # 2) 拷贝电脑端
    if ($cbPc.Checked) {
        L "复制电脑端文件…"
        $src1 = $srcPcDir
        $src2 = $srcScrDir
        foreach ($pair in @(@{s=$src1; d=(Join-Path $target "pc-mode")}, @{s=$src2; d=(Join-Path $target "scrcpy-win64-v5.0.1")})) {
            if (Test-Path $pair.s) {
                $null = robocopy $pair.s $pair.d /E /NFL /NDL /NJH /NJS /NP 2>&1
                L ("  ✓ " + (Split-Path $pair.s -Leaf))
            } else { L ("  ! 缺少 " + (Split-Path $pair.s -Leaf)) }
        }
    }

    # 4) 桌面快捷方式
    if ($cbShortcut.Checked) {
        try {
            $ws = New-Object -ComObject WScript.Shell
            $desk = [Environment]::GetFolderPath('Desktop')
            $lnk = $ws.CreateShortcut((Join-Path $desk "手机主机.lnk"))
            $lnk.TargetPath = "cmd.exe"
            $lnk.Arguments = "/c `"$target\pc-mode\启动.bat`""
            $lnk.WorkingDirectory = Join-Path $target "pc-mode"
            $lnk.WindowStyle = 7
            $lnk.Description = "手机主机 · 控制台"
            $lnk.Save()
            L "✓ 桌面快捷方式已创建"
        } catch { L "! 创建快捷方式失败：$($_.Exception.Message)" }
    }

    # 5) 计划任务
    if ($cbTask.Checked) {
        try {
            $tr = "cmd /c `"$target\pc-mode\watch-reconnect.bat`""
            & schtasks /create /tn "PhoneHost-WatchReconnect" /tr $tr /sc minute /mo 5 /f 2>&1 | Out-Null
            L "✓ 计划任务已注册（每 5 分钟检查守护）"
        } catch { L "! 计划任务注册失败（可能无权限）" }
    }

    L "=== 安装完成 ==="
    L "启动方式：桌面「手机主机」或 $target\pc-mode\启动.bat"
    L "手机端：打开控制台 → 点 ⑦ 装手机端（手机插数据线、开 USB 调试）"

    if ($cbRun.Checked) {
        L "正在启动…"
        Start-Process cmd.exe -ArgumentList "/c","启动.bat" -WorkingDirectory (Join-Path $target "pc-mode") -WindowStyle Hidden
    }
    $btnInstall.Enabled = $true
})

[void]$form.ShowDialog()
