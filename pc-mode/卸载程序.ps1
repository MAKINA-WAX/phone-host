# 手机主机 · 卸载程序（图形界面）
# 删除程序文件、桌面快捷方式、计划任务；可选通过数据线卸载手机端 5 个 APK
$ErrorActionPreference = "Continue"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -Name Dp -Namespace Uninst -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);'
[void][Uninst.Dp]::SetProcessDpiAwarenessContext([IntPtr](-4))

$dpi = 96
try { $g = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero); $dpi = $g.DpiX; $g.Dispose() } catch {}
$s = $dpi / 96.0
function S([double]$v) { [int][math]::Round($v * $s) }

$form = New-Object System.Windows.Forms.Form
$form.Text = "手机主机 · 卸载程序"
$form.ClientSize = New-Object System.Drawing.Size((S 600), (S 500))
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 246, 248)
$form.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)

$title = New-Object System.Windows.Forms.Label
$title.Text = "手机主机 · 卸载程序"
$title.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 15, [System.Drawing.FontStyle]::Bold)
$title.Location = New-Object System.Drawing.Point((S 22), (S 18))
$title.AutoSize = $true
$form.Controls.Add($title)

$sub = New-Object System.Windows.Forms.Label
$sub.Text = "删除程序文件、桌面快捷方式、计划任务；手机里的 APK 也可以一起卸载"
$sub.ForeColor = [System.Drawing.Color]::FromArgb(110, 110, 118)
$sub.Location = New-Object System.Drawing.Point((S 24), (S 56))
$sub.AutoSize = $true
$form.Controls.Add($sub)

$lblDir = New-Object System.Windows.Forms.Label
$lblDir.Text = "安装目录："
$lblDir.Location = New-Object System.Drawing.Point((S 24), (S 92))
$lblDir.AutoSize = $true
$form.Controls.Add($lblDir)

$txtDir = New-Object System.Windows.Forms.TextBox
$txtDir.Text = "C:\PhoneHost"
$txtDir.Location = New-Object System.Drawing.Point((S 100), (S 88))
$txtDir.Size = New-Object System.Drawing.Size((S 380), (S 26))
$form.Controls.Add($txtDir)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "浏览…"
$btnBrowse.Location = New-Object System.Drawing.Point((S 488), (S 87))
$btnBrowse.Size = New-Object System.Drawing.Size((S 88), (S 28))
$form.Controls.Add($btnBrowse)
$btnBrowse.add_Click({
    $fb = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($fb.ShowDialog() -eq "OK") { $txtDir.Text = $fb.SelectedPath }
})

$gb = New-Object System.Windows.Forms.GroupBox
$gb.Text = "卸载内容"
$gb.Location = New-Object System.Drawing.Point((S 24), (S 126))
$gb.Size = New-Object System.Drawing.Size((S 552), (S 150))
$form.Controls.Add($gb)

$cbFiles = New-Object System.Windows.Forms.CheckBox
$cbFiles.Text = "删除程序文件（整个安装目录）"
$cbFiles.Checked = $true
$cbFiles.Location = New-Object System.Drawing.Point((S 16), (S 28))
$cbFiles.AutoSize = $true
$gb.Controls.Add($cbFiles)

$cbShortcut = New-Object System.Windows.Forms.CheckBox
$cbShortcut.Text = "删除桌面快捷方式「手机主机」"
$cbShortcut.Checked = $true
$cbShortcut.Location = New-Object System.Drawing.Point((S 16), (S 56))
$cbShortcut.AutoSize = $true
$gb.Controls.Add($cbShortcut)

$cbTask = New-Object System.Windows.Forms.CheckBox
$cbTask.Text = "删除计划任务 PhoneHost-WatchReconnect"
$cbTask.Checked = $true
$cbTask.Location = New-Object System.Drawing.Point((S 16), (S 84))
$cbTask.AutoSize = $true
$gb.Controls.Add($cbTask)

$cbApk = New-Object System.Windows.Forms.CheckBox
$cbApk.Text = "通过数据线卸载手机端 5 个 APK（Termux 全家桶）"
$cbApk.Checked = $false
$cbApk.Location = New-Object System.Drawing.Point((S 16), (S 112))
$cbApk.AutoSize = $true
$gb.Controls.Add($cbApk)

$warn = New-Object System.Windows.Forms.Label
$warn.Text = "⚠ 手机端卸载会连 Termux 和里面的 Linux 一起删掉，装回去要重新配置。"
$warn.ForeColor = [System.Drawing.Color]::FromArgb(190, 80, 60)
$warn.Location = New-Object System.Drawing.Point((S 24), (S 282))
$warn.AutoSize = $true
$form.Controls.Add($warn)

$log = New-Object System.Windows.Forms.TextBox
$log.Multiline = $true
$log.ScrollBars = "Vertical"
$log.ReadOnly = $true
$log.BackColor = [System.Drawing.Color]::FromArgb(24, 26, 30)
$log.ForeColor = [System.Drawing.Color]::FromArgb(220, 220, 225)
$log.Font = New-Object System.Drawing.Font("Consolas", 8.5)
$log.Location = New-Object System.Drawing.Point((S 24), (S 310))
$log.Size = New-Object System.Drawing.Size((S 552), (S 140))
$form.Controls.Add($log)

$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "开始卸载"
$btnRun.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 10, [System.Drawing.FontStyle]::Bold)
$btnRun.Location = New-Object System.Drawing.Point((S 340), (S 456))
$btnRun.Size = New-Object System.Drawing.Size((S 110), (S 34))
$form.Controls.Add($btnRun)

$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "退出"
$btnExit.Location = New-Object System.Drawing.Point((S 462), (S 456))
$btnExit.Size = New-Object System.Drawing.Size((S 110), (S 34))
$form.Controls.Add($btnExit)
$btnExit.add_Click({ $form.Close() })

function L([string]$m) {
    $log.AppendText("[" + (Get-Date -Format 'HH:mm:ss') + "] $m`r`n")
    $log.SelectionStart = $log.TextLength
    $log.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

$btnRun.add_Click({
    $target = $txtDir.Text.Trim()

    $ans = [System.Windows.Forms.MessageBox]::Show(
        "确定要卸载吗？`r`n`r`n目录: $target`r`n" +
        $(if ($cbApk.Checked) { "`r`n⚠ 还会卸载手机端的 5 个 APK（Termux 里的 Linux 会一起没）" } else { "" }),
        "确认卸载", "YesNo", "Warning")
    if ($ans -ne "Yes") { return }

    $btnRun.Enabled = $false
    L "=== 开始卸载 ==="

    # 1) 先停进程
    L "停止相关进程…"
    Get-Process scrcpy -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    $me = $PID
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessId -ne $me -and $_.CommandLine -match 'watch-reconnect|tray\.ps1|pc-launcher|start-lxqt|start-xfce|mirror-phone' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    L "  ✓ 已停止投屏 / 守护 / 托盘"

    # 2) 删计划任务
    if ($cbTask.Checked) {
        $r = & schtasks /delete /tn "PhoneHost-WatchReconnect" /f 2>&1
        if ($r -match "成功|SUCCESS") { L "  ✓ 计划任务已删除" } else { L "  · 计划任务不存在或删除失败" }
    }

    # 3) 删快捷方式
    if ($cbShortcut.Checked) {
        $desk = [Environment]::GetFolderPath('Desktop')
        foreach ($n in @("手机主机.lnk")) {
            $p = Join-Path $desk $n
            if (Test-Path $p) { Remove-Item $p -Force -ErrorAction SilentlyContinue; L "  ✓ 已删除桌面快捷方式 $n" }
        }
    }

    # 4) 手机端 APK
    if ($cbApk.Checked) {
        $adb = Join-Path $target "scrcpy-win64-v5.0.1\adb.exe"
        if (-not (Test-Path $adb)) { $adb = "adb" }
        $dev = ((& $adb devices 2>&1) -join "`n")
        if ($dev -notmatch "(?m)^\S+\s+device\s*$") {
            L "  ! 手机没连（或没授权 USB 调试），跳过手机端卸载"
        } else {
            $pkgs = @("com.termux","com.termux.x11","com.termux.api","com.termux.boot","com.termux.widget")
            foreach ($p in $pkgs) {
                $r = ((& $adb -d uninstall $p 2>&1) -join " ")
                if ($r -match "Success") { L "  ✓ 已卸载 $p" }
                elseif ($r -match "not installed") { L "  · $p 本来就没装" }
                else { L ("  ! $p 卸载失败: " + ($r.Trim() -replace "\s+"," ")) }
            }
        }
    }

    # 5) 删目录
    if ($cbFiles.Checked) {
        if (Test-Path $target) {
            L "删除目录 $target …"
            Remove-Item $target -Recurse -Force -ErrorAction SilentlyContinue
            if (Test-Path $target) {
                L "  ! 有文件占用，删不干净。请手动删除或重启后再试"
            } else {
                L "  ✓ 目录已删除"
            }
        } else {
            L "  · 目录不存在，跳过"
        }
    }

    L "=== 卸载完成 ==="
    $btnRun.Enabled = $true
})

[void]$form.ShowDialog()
