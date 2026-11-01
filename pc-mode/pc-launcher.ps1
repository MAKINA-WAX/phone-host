# 手机主机 · 控制台（DPI 适配重制版）
# 关键：先切成 per-monitor DPI aware，再按 dpi/96 缩放全部尺寸与字号。
# 否则在 200% 缩放下 Windows 会整窗位图拉伸 → 模糊 + 尺寸不像 PC 应用。
$ErrorActionPreference = "Continue"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type -Name Ui -Namespace Dpi -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
[DllImport("user32.dll")] public static extern uint GetDpiForSystem();
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
'@
[void][Dpi.Ui]::SetProcessDpiAwarenessContext([IntPtr](-4))
$sysDpi = [Dpi.Ui]::GetDpiForSystem()
if ($sysDpi -lt 96) { $sysDpi = 96 }
$s = $sysDpi / 96.0
$uiK = 0.70
function S([double]$v) { [int][math]::Round($v * $s * $uiK) }

$root = $PSScriptRoot
$localTemp = Join-Path $root "tmp"
if (-not (Test-Path $localTemp)) { New-Item -ItemType Directory -Path $localTemp -Force | Out-Null }
$env:TEMP = $localTemp
$env:TMP = $localTemp
$adb = Join-Path (Split-Path $root -Parent) "scrcpy-win64-v5.0.1\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }

# ---------------- 配置 ----------------
$cfgPath = Join-Path $root "launcher.json"
$cfg = @{ bitrate = "40M"; fps = "60"; startApp = "com.android.chrome"; uiScale = 0.70; mode = "off" }
if (Test-Path $cfgPath) {
    try {
        $loaded = Get-Content $cfgPath -Raw | ConvertFrom-Json
        foreach ($k in @("bitrate", "fps", "startApp", "uiScale", "mode")) { if ($null -ne $loaded.$k -and "$($loaded.$k)" -ne "") { $cfg[$k] = $loaded.$k } }
    } catch { }
}
function Save-Cfg { $cfg | ConvertTo-Json | Set-Content $cfgPath -Encoding UTF8 }
try { $uiK = [double]$cfg.uiScale } catch { $uiK = 0.70 }
if ($uiK -lt 0.6 -or $uiK -gt 1.4) { $uiK = 0.70 }

# ---------------- 主题 ----------------
$cBg     = [System.Drawing.Color]::FromArgb(22, 24, 28)
$cPanel  = [System.Drawing.Color]::FromArgb(32, 35, 41)
$cBtn    = [System.Drawing.Color]::FromArgb(47, 52, 61)
$cBtnHot = [System.Drawing.Color]::FromArgb(60, 67, 79)
$cBorder = [System.Drawing.Color]::FromArgb(66, 72, 84)
$cAccent = [System.Drawing.Color]::FromArgb(96, 190, 255)
$cText   = [System.Drawing.Color]::FromArgb(226, 232, 240)
$cDim    = [System.Drawing.Color]::FromArgb(150, 158, 170)
$cWarn   = [System.Drawing.Color]::FromArgb(240, 200, 110)

$fTitle = New-Object System.Drawing.Font("Microsoft YaHei UI", (11 * $s * $uiK), [System.Drawing.FontStyle]::Bold)
$fBase  = New-Object System.Drawing.Font("Microsoft YaHei UI", (9 * $s * $uiK))
$fSmall = New-Object System.Drawing.Font("Microsoft YaHei UI", (8.5 * $s * $uiK))
$fMono  = New-Object System.Drawing.Font("Consolas", (9 * $s * $uiK))

# ---------------- 窗体 ----------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "手机主机 · 控制台"
$form.ClientSize = New-Object System.Drawing.Size((S 664), (S 786))
$form.MinimumSize = New-Object System.Drawing.Size((S 700), (S 720))
$form.StartPosition = "CenterScreen"
$form.BackColor = $cBg
$form.ForeColor = $cText
$form.Font = $fBase
$form.Padding = New-Object System.Windows.Forms.Padding((S 12))

# ---------------- 顶部状态卡 ----------------
$card = New-Object System.Windows.Forms.Panel
$card.Dock = "Top"
$card.Height = (S 96)
$card.BackColor = $cPanel
$card.Padding = New-Object System.Windows.Forms.Padding((S 12), (S 6), (S 12), (S 6))

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "手机主机 · 控制台"
$lblTitle.Font = $fTitle
$lblTitle.ForeColor = $cAccent
$lblTitle.Dock = "Top"
$lblTitle.Height = (S 26)
$lblTitle.TextAlign = "MiddleLeft"

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Dock = "Fill"
$lblStatus.Font = $fMono
$lblStatus.ForeColor = $cDim
$lblStatus.Text = "读取中…"
$lblStatus.AutoSize = $false

$card.Controls.Add($lblStatus)
$card.Controls.Add($lblTitle)

# ---------------- 按钮区 ----------------
$flow = New-Object System.Windows.Forms.Panel
$flow.Dock = "Top"
$flow.Height = (S 200)
$flow.BackColor = $cBg
$flow.Padding = New-Object System.Windows.Forms.Padding(0, (S 10), 0, (S 4))

function New-Button($text, $tip, $x, $y, $w = 236, $h = 46) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Font = $fBase
    $b.SetBounds((S $x), (S $y), (S $w), (S $h))
    $b.FlatStyle = "Flat"
    $b.FlatAppearance.BorderSize = 1
    $b.FlatAppearance.BorderColor = $cBorder
    $b.FlatAppearance.MouseOverBackColor = $cBtnHot
    $b.BackColor = $cBtn
    $b.ForeColor = $cText
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    if ($tip) {
        $tt = New-Object System.Windows.Forms.ToolTip
        $tt.SetToolTip($b, $tip)
    }
    $flow.Controls.Add($b)
    return $b
}

# ---------------- 日志 ----------------
$log = New-Object System.Windows.Forms.TextBox
$log.Multiline = $true
$log.ScrollBars = "Vertical"
$log.ReadOnly = $true
$log.Dock = "Fill"
$log.BackColor = [System.Drawing.Color]::FromArgb(15, 17, 21)
$log.ForeColor = [System.Drawing.Color]::FromArgb(186, 198, 212)
$log.Font = $fMono
$log.BorderStyle = "FixedSingle"
$log.Margin = New-Object System.Windows.Forms.Padding(0, (S 6), 0, 0)

function Log($msg) {
    $log.AppendText(("[{0}] {1}`r`n" -f (Get-Date -Format "HH:mm:ss"), $msg))
    $log.SelectionStart = $log.Text.Length
    $log.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function RunScript($name, $extra = @()) {
    $path = Join-Path $root $name
    if (-not (Test-Path $path)) { Log "缺少 $name"; return }
    Log "▶ $name"
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $path @extra 2>&1
    foreach ($line in ($out -split "`n")) { if ("$line".Trim()) { Log ("   " + "$line".Trim()) } }
}

# ---------------- 底部设置 ----------------
$setPanel = New-Object System.Windows.Forms.Panel
$setPanel.Dock = "Bottom"
$setPanel.Height = (S 142)
$setPanel.BackColor = $cPanel
$setPanel.Padding = New-Object System.Windows.Forms.Padding((S 12), (S 6), (S 12), (S 6))

$lblSet = New-Object System.Windows.Forms.Label
$lblSet.Text = "投屏参数"
$lblSet.Font = $fSmall
$lblSet.ForeColor = $cAccent
$lblSet.Dock = "Top"
$lblSet.Height = (S 22)
$lblSet.TextAlign = "MiddleLeft"

$row = New-Object System.Windows.Forms.FlowLayoutPanel
$row.Dock = "Top"
$row.Height = (S 38)
$row.WrapContents = $false

function New-FieldLabel($t) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $t
    $l.Font = $fSmall
    $l.ForeColor = $cDim
    $l.AutoSize = $true
    $l.Margin = New-Object System.Windows.Forms.Padding((S 2), (S 9), (S 4), 0)
    return $l
}

$cmbRate = New-Object System.Windows.Forms.ComboBox
$cmbRate.Font = $fSmall
$cmbRate.Size = New-Object System.Drawing.Size((S 82), (S 26))
$cmbRate.DropDownStyle = "DropDownList"
[void]$cmbRate.Items.AddRange(@("20M", "40M", "60M", "80M"))
$cmbRate.SelectedItem = $cfg.bitrate
if (-not $cmbRate.SelectedItem) { $cmbRate.SelectedIndex = 1 }

$cmbFps = New-Object System.Windows.Forms.ComboBox
$cmbFps.Font = $fSmall
$cmbFps.Size = New-Object System.Drawing.Size((S 68), (S 26))
$cmbFps.DropDownStyle = "DropDownList"
[void]$cmbFps.Items.AddRange(@("30", "60", "90", "120"))
$cmbFps.SelectedItem = $cfg.fps
if (-not $cmbFps.SelectedItem) { $cmbFps.SelectedIndex = 1 }

$txtApp = New-Object System.Windows.Forms.TextBox
$txtApp.Font = $fSmall
$txtApp.Size = New-Object System.Drawing.Size((S 164), (S 26))
$txtApp.Text = $cfg.startApp

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = "保存"
$btnSave.Font = $fSmall
$btnSave.AutoSize = $true
$btnSave.Padding = New-Object System.Windows.Forms.Padding((S 10), (S 2), (S 10), (S 2))
$btnSave.FlatStyle = "Flat"
$btnSave.FlatAppearance.BorderColor = $cBorder
$btnSave.BackColor = $cBtn
$btnSave.ForeColor = $cText
$btnSave.Add_Click({
    $cfg.bitrate = $cmbRate.SelectedItem
    $cfg.fps = $cmbFps.SelectedItem
    $cfg.startApp = $txtApp.Text.Trim()
    Save-Cfg
    Log "已保存：码率 $($cfg.bitrate) / 帧率 $($cfg.fps) / 起始 App $($cfg.startApp)"
})

[void]$row.Controls.Add((New-FieldLabel "码率"))
[void]$row.Controls.Add($cmbRate)
[void]$row.Controls.Add((New-FieldLabel "帧率"))
[void]$row.Controls.Add($cmbFps)
[void]$row.Controls.Add((New-FieldLabel "App"))
[void]$row.Controls.Add($txtApp)
[void]$row.Controls.Add($btnSave)

$lblTip = New-Object System.Windows.Forms.Label
$lblTip.Text = "提示：别按 Alt+F；窗口被盖住用 bring-back.bat"
$lblTip.Font = $fSmall
$lblTip.ForeColor = $cDim
$lblTip.Dock = "Bottom"
$lblTip.Height = (S 24)
$lblTip.TextAlign = "MiddleLeft"

# 第二行：界面缩放
$row2 = New-Object System.Windows.Forms.FlowLayoutPanel
$row2.Dock = "Fill"
$row2.WrapContents = $false

$cmbUi = New-Object System.Windows.Forms.ComboBox
$cmbUi.Font = $fSmall
$cmbUi.Size = New-Object System.Drawing.Size((S 66), (S 26))
$cmbUi.DropDownStyle = "DropDownList"
[void]$cmbUi.Items.AddRange(@("70%", "80%", "85%", "100%", "115%"))
$cmbUi.SelectedItem = ([int][math]::Round($uiK * 100)).ToString() + "%"
if (-not $cmbUi.SelectedItem) { $cmbUi.SelectedIndex = 2 }

$btnUi = New-Object System.Windows.Forms.Button
$btnUi.Text = "应用"
$btnUi.Font = $fSmall
$btnUi.AutoSize = $true
$btnUi.Padding = New-Object System.Windows.Forms.Padding((S 10), (S 2), (S 10), (S 2))
$btnUi.FlatStyle = "Flat"
$btnUi.FlatAppearance.BorderColor = $cBorder
$btnUi.BackColor = $cBtn
$btnUi.ForeColor = $cText
$btnUi.Add_Click({
    $v = [double](([string]$cmbUi.SelectedItem).TrimEnd('%')) / 100.0
    $cfg.uiScale = $v
    Save-Cfg
    Log "界面缩放改为 $($cmbUi.SelectedItem)，重启界面…"
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "启动.bat" -WorkingDirectory $root -WindowStyle Hidden
    $form.Close()
})

[void]$row2.Controls.Add((New-FieldLabel "界面缩放"))
[void]$row2.Controls.Add($cmbUi)
[void]$row2.Controls.Add($btnUi)

$sgrid = New-Object System.Windows.Forms.TableLayoutPanel
$sgrid.Dock = "Fill"
$sgrid.ColumnCount = 1
$sgrid.RowCount = 4
[void]$sgrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$sgrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, (S 40))))
[void]$sgrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, (S 36))))
[void]$sgrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
$lblSet.Dock = "Fill"
$row.Dock = "Fill"
$lblTip.Dock = "Fill"
$lblTip.Height = (S 24)
[void]$sgrid.Controls.Add($lblSet, 0, 0)
[void]$sgrid.Controls.Add($row, 0, 1)
[void]$sgrid.Controls.Add($row2, 0, 2)
[void]$sgrid.Controls.Add($lblTip, 0, 3)
$setPanel.Controls.Add($sgrid)

# ---------------- 状态 / 恢复 ----------------
function Get-TopActivity {
    ((& $adb -d shell "dumpsys activity activities | grep -m1 topResumedActivity" 2>&1) -join "")
}

# ---------------- 后台探测（所有 adb 查询放后台，UI 不再卡） ----------------
$shared = [hashtable]::Synchronized(@{
    ready = $false; dev = $false; model = ""; pct = "-"; temp = "-"; plug = "-"
    disps = ""; top = ""; scrcpy = $false; black = $false
})
$rs = [runspacefactory]::CreateRunspace()
$rs.Open()
$probe = [powershell]::Create()
$probe.Runspace = $rs
[void]$probe.AddScript({
    param($adbPath, $st)
    function Sh([string]$c) { try { return (((& $adbPath -d shell $c 2>&1) -join "`n")) } catch { return "" } }
    while ($true) {
        try {
            $o = ((& $adbPath devices 2>&1) -join "`n")
            $st.dev = ($o -match "(?m)^\S+\s+device\s*$")
            $st.scrcpy = [bool](Get-Process scrcpy -ErrorAction SilentlyContinue)
            $st.black = $false
            if ($st.scrcpy) {
                try {
                    $pw = Get-Process scrcpy -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
                    if ($pw) {
                        $rr = New-Object Dpi.Ui+RECT
                        if ([Dpi.Ui]::GetWindowRect($pw.MainWindowHandle, [ref]$rr)) {
                            $ww = $rr.Right - $rr.Left; $hh = $rr.Bottom - $rr.Top
                            if ($ww -gt 60 -and $hh -gt 60) {
                                $sw = [int]($ww * 0.25); $sh = [int]($hh * 0.25)
                                $bmp = New-Object System.Drawing.Bitmap $sw, $sh
                                $gg = [System.Drawing.Graphics]::FromImage($bmp)
                                $gg.CopyFromScreen(($rr.Left + [int](($ww-$sw)/2)), ($rr.Top + [int](($hh-$sh)/2)), 0, 0, (New-Object System.Drawing.Size $sw, $sh))
                                $gg.Dispose()
                                $sum = 0.0; $nn = 0
                                for ($x = 0; $x -lt $sw; $x += 9) {
                                    for ($y = 0; $y -lt $sh; $y += 9) {
                                        $cc = $bmp.GetPixel($x, $y); $sum += ($cc.R + $cc.G + $cc.B) / 3.0; $nn++
                                    }
                                }
                                $bmp.Dispose()
                                if ($nn -gt 0) { $st.black = (($sum / $nn) -lt 12) }
                            }
                        }
                    }
                } catch {}
            }
            if ($st.dev) {
                if (-not $st.model) { $st.model = (Sh "getprop ro.product.model").Trim() }
                $bat = Sh "run-as com.termux sh -c 'export PATH=/data/data/com.termux/files/usr/bin:$PATH; export LD_LIBRARY_PATH=/data/data/com.termux/files/usr/lib; termux-battery-status 2>/dev/null'"
                $pct = "-"; $tmp = "-"; $plg = "-"
                if ($bat -match '"percentage":\s*(\d+)') { $pct = $Matches[1] + "%" }
                if ($bat -match '"temperature":\s*([\d\.]+)') { $tmp = $Matches[1] + "C" }
                if ($bat -match '"plugged":\s*"(\w+)"') { $plg = $Matches[1] -replace "PLUGGED_", "" }
                $st.pct = $pct; $st.temp = $tmp; $st.plug = $plg
                $d = Sh "dumpsys display | grep -o -E 'displayId [0-9]+'"
                $st.disps = ((($d -split "`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique) -join ", ")
                $topOut = Sh "dumpsys activity activities | grep -m1 topResumedActivity"
                if ($topOut -match 'topResumedActivity=ActivityRecord\{\S+\s+\S+\s+(\S+)') { $st.top = $Matches[1] } else { $st.top = $topOut.Trim() }
            }
            $st.ready = $true
        } catch {}
        Start-Sleep -Seconds 3
    }
}).AddArgument($adb).AddArgument($shared)
$probeHandle = $probe.BeginInvoke()
function Update-Status {
    if (-not [bool]$shared.ready) { return }
    if (-not [bool]$shared.dev) {
        $lblStatus.ForeColor = $cWarn
        $lblStatus.Text = "未连接手机（插数据线 + 打开 USB 调试）"
        return
    }
    $top = [string]$shared.top
    $screen = if ($top -match "termux\.x11") { "Linux 桌面" } elseif ($top -match "chrome") { "Chrome（占位）" } else { "其他" }
    $lblStatus.ForeColor = $cDim
    $lblStatus.Text = ("{0}    {1}    {2}    电源 {3}`r`n虚拟屏 {4}    前台 {5}" -f ([string]$shared.model), ([string]$shared.pct), ([string]$shared.temp), ([string]$shared.plug), ([string]$shared.disps), $screen)
}
$script:lastRecover = [datetime]::MinValue
function Test-BlackMirror {
    $p = Get-Process scrcpy -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if (-not $p) { return $false }
    if ([Dpi.Ui]::GetForegroundWindow() -ne $p.MainWindowHandle) { return $false }
    $r = New-Object Dpi.Ui+RECT
    [void][Dpi.Ui]::GetWindowRect($p.MainWindowHandle, [ref]$r)
    $w = $r.Right - $r.Left; $h = $r.Bottom - $r.Top
    if ($w -le (S 100) -or $h -le (S 100)) { return $false }
    $cx = $r.Left + [int]($w / 2) - [int]($w * 0.05)
    $cy = $r.Top + [int]($h / 2) - [int]($h * 0.05)
    $bmp = New-Object System.Drawing.Bitmap (S 80), (S 80)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try { $g.CopyFromScreen($cx, $cy, 0, 0, $bmp.Size) } catch { $g.Dispose(); $bmp.Dispose(); return $false }
    $sum = 0.0; $n = 0
    $step = [int](S 8)
    if ($step -lt 1) { $step = 1 }
    for ($x = 0; $x -lt $bmp.Width; $x += $step) {
        for ($y = 0; $y -lt $bmp.Height; $y += $step) {
            $c = $bmp.GetPixel($x, $y); $sum += ($c.R + $c.G + $c.B) / 3.0; $n++
        }
    }
    $g.Dispose(); $bmp.Dispose()
    if ($n -eq 0) { return $false }
    $avg = $sum / $n
    return ($avg -lt 12)
}

function Try-Recover {
    # 只有桌面模式才自动恢复；且全部基于后台缓存，不再阻塞 UI
    if ("$($cfg.mode)" -ne "desktop") { return }
    if (-not [bool]$shared.ready -or -not [bool]$shared.dev) { return }
    if (-not [string]$shared.disps -match 'displayId (\d+)' -or [int]$Matches[1] -eq 0) { return }
    $ok = ([string]$shared.top -match "termux\.x11") -and -not [bool]$shared.black
    if (-not $ok -and ((Get-Date) - $script:lastRecover).TotalSeconds -gt 90) {
        $script:lastRecover = Get-Date
        Log "检测到桌面丢失或黑屏 → 先尝试只重画（不关程序）…"
        Start-Process powershell -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File",(Join-Path $PSScriptRoot "start-xfce.ps1"),"-Attach" -WindowStyle Hidden
    }
}
# ---------------- 按钮布局（3 列 × 3 行） ----------------
$bw = 202; $bh = 42; $gapX = 10; $gapY = 10
$items = @(
    @{ t = "① 环境检测";    tip = "只读检测环境是否就绪";                    a = { RunScript "doctor.ps1" } },
    @{ t = "② 开画布";      tip = "自适应分辨率建虚拟屏并铺满";              a = { RunScript "auto-start.ps1" } },
    @{ t = "③ 开 Linux"; tip = "启动 XFCE 并全屏显示";                  a = { $cfg.mode = "desktop"; Save-Cfg; RunScript "start-xfce.ps1" } },
    @{ t = "④ 切回桌面";    tip = "不重启，只切回已运行的桌面";              a = { $cfg.mode = "desktop"; Save-Cfg; RunScript "start-xfce.ps1" @("-Attach") } },
    @{ t = "⑤ 切安卓App"; tip = "全屏打开下方填写的包名";                 a = { $p = $txtApp.Text.Trim(); if ($p) { RunScript "open-app.ps1" @($p) } else { Log "先填包名" } } },
    @{ t = "⑥ 手机镜像";  tip = "直接镜像手机本机屏，不开虚拟屏";         a = { $cfg.mode = "mirror"; Save-Cfg; RunScript "mirror-phone.ps1" @("-BitRate", "$($cfg.bitrate)", "-Fps", "$($cfg.fps)") } },
    @{ t = "⑦ 补齐环境"; tip = "装 APK / XFCE / 偏好 / 加固";            a = { RunScript "provision.ps1" } },
    @{ t = "⑧ 加固后台";    tip = "appops + 活跃桶 + Doze 白名单";            a = { RunScript "harden.ps1" } },
    @{ t = "⑨ 收工清理";  tip = "关窗口 + 杀 server + 清虚拟屏";           a = { $cfg.mode = "off"; Save-Cfg; RunScript "stop-pc.bat" } },
    @{ t = "⑩ 防烧屏";    tip = "把手机面板真正熄掉（虚拟屏内容不受影响）";  a = { RunScript "anti-burn.ps1" @("-On") } },
    @{ t = "⑪ 唤醒屏幕";  tip = "把手机屏幕点亮";                          a = { RunScript "anti-burn.ps1" @("-Off") } }
)
for ($i = 0; $i -lt $items.Count; $i++) {
    $col = $i % 3
    $rowIdx = [math]::Floor($i / 3)
    $btn = New-Button $items[$i].t $items[$i].tip ($col * ($bw + $gapX)) ($rowIdx * ($bh + $gapY)) $bw $bh
    $btn.Add_Click($items[$i].a)
}

# ---------------- 组装：用 TableLayoutPanel 固定 4 行，避免 Dock 互相压 ----------------
$grid = New-Object System.Windows.Forms.TableLayoutPanel
$grid.Dock = "Fill"
$grid.ColumnCount = 1
$grid.RowCount = 4
[void]$grid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$grid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$grid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$grid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
$card.Dock = "Fill"
$flow.Dock = "Fill"
$log.Dock = "Fill"
$setPanel.Dock = "Fill"
[void]$grid.Controls.Add($card, 0, 0)
[void]$grid.Controls.Add($flow, 0, 1)
[void]$grid.Controls.Add($log, 0, 2)
[void]$grid.Controls.Add($setPanel, 0, 3)
[void]$form.Controls.Add($grid)

$form.Add_Shown({
    Log ("DPI {0}（缩放 {1}%），界面已按此缩放" -f $sysDpi, [int]($s * 100))
    Update-Status
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000
    $timer.Add_Tick({ Update-Status; Try-Recover })
    $timer.Start()
})

[void]$form.ShowDialog()
