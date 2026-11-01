# 交互式操作引导（5 步）—— UI 线程只负责刷新，所有检测都放在后台 runspace，避免卡死
$ErrorActionPreference = "Continue"
$root = $PSScriptRoot
$localTemp = Join-Path $root "tmp"
if (-not (Test-Path $localTemp)) { New-Item -ItemType Directory -Path $localTemp -Force | Out-Null }
$env:TEMP = $localTemp
$env:TMP = $localTemp

$adb = Join-Path (Split-Path $root -Parent) "scrcpy-win64-v5.0.1\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -Name DpiG -Namespace Gd3 -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);'
[void][Gd3.DpiG]::SetProcessDpiAwarenessContext([IntPtr](-4))

$dpi = 96
try { $gfx = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero); $dpi = $gfx.DpiX; $gfx.Dispose() } catch {}
$s = $dpi / 96.0
function S([double]$v) { [int][math]::Round($v * $s) }

# ---------- 后台探测（不阻塞 UI） ----------
$shared = [hashtable]::Synchronized(@{ adb = "?"; link = $false; scrcpy = $false; ready = $false })
$rs = [runspacefactory]::CreateRunspace()
$rs.Open()
$probe = [powershell]::Create()
$probe.Runspace = $rs
[void]$probe.AddScript({
    param($adbPath, $store)
    function AdbState {
        try {
            $o = (& $adbPath devices 2>&1) -join "`n"
            if ($o -match "(?m)^\S+\s+unauthorized\s*$") { return "unauthorized" }
            if ($o -match "(?m)^\S+\s+offline\s*$") { return "offline" }
            if ($o -match "(?m)^\S+\s+device\s*$") { return "device" }
            return "none"
        } catch { return "none" }
    }
    function LinkPresent {
        try {
            $r = Get-CimInstance Win32_PnPEntity -Filter "DeviceID LIKE 'USB\\VID_2717%'" -ErrorAction Stop
            return [bool]$r
        } catch { return $false }
    }
    while ($true) {
        $store.adb = AdbState
        $store.link = LinkPresent
        $store.scrcpy = [bool](Get-Process scrcpy -ErrorAction SilentlyContinue)
        $store.ready = $true
        Start-Sleep -Milliseconds 1500
    }
}).AddArgument($adb).AddArgument($shared)
$probeHandle = $probe.BeginInvoke()

# ---------- UI ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = "操作引导"
$form.ClientSize = New-Object System.Drawing.Size((S 690), (S 400))
$form.StartPosition = "CenterScreen"
$form.TopMost = $true
$form.BackColor = [System.Drawing.Color]::FromArgb(24, 26, 30)
$form.ForeColor = [System.Drawing.Color]::White
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None

function MkLabel($pt, $y, $h, $color, $bold) {
    $l = New-Object System.Windows.Forms.Label
    $style = if ($bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $l.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", $pt, $style)
    $l.ForeColor = $color
    $l.Location = New-Object System.Drawing.Point((S 22), (S $y))
    $l.Size = New-Object System.Drawing.Size((S 646), (S $h))
    $l.AutoSize = $false
    $form.Controls.Add($l)
    return $l
}

$lblStep  = MkLabel 9    14  22  ([System.Drawing.Color]::FromArgb(110, 165, 255)) $false
$lblBig   = MkLabel 13.5 42  54  ([System.Drawing.Color]::White) $true
$lblHint  = MkLabel 9.5  104 120 ([System.Drawing.Color]::FromArgb(198, 200, 206)) $false
$lblState = MkLabel 8.5  238 100 ([System.Drawing.Color]::FromArgb(135, 200, 140)) $false

$btn = New-Object System.Windows.Forms.Button
$btn.Text = "关闭"
$btn.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)
$btn.Size = New-Object System.Drawing.Size((S 94), (S 30))
$btn.Location = New-Object System.Drawing.Point((S 570), (S 352))
$btn.FlatStyle = "Flat"
$btn.add_Click({ $form.Close() })
$form.Controls.Add($btn)

$state = @{ step = 1; absentAt = $null; backAt = $null }

function Set-Step($n, $big, $hint, $stateText) {
    $lblStep.Text  = "第 $n 步 / 共 5 步"
    $lblBig.Text   = $big
    $lblHint.Text  = $hint
    $lblState.Text = $stateText
}

Set-Step 1 "请拔掉手机数据线" "拔掉后什么也别做，等我自动检测。" ""

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 400
$timer.add_Tick({
    try {
        if (-not [bool]$shared.ready) { return }
        $adbState = [string]$shared.adb
        $link = [bool]$shared.link
        $scrcpy = [bool]$shared.scrcpy

        switch ($state.step) {
            1 {
                $lblState.Text = "adb: $adbState`r`nUSB 连接: " + $(if ($link) { "在" } else { "已拔" })
                if (-not $link) {
                    $state.step = 2; $state.absentAt = Get-Date
                    Set-Step 2 "已断开 OK" "停 5 秒，然后把数据线插回去。" ""
                }
            }
            2 {
                $gone = [int]((Get-Date) - $state.absentAt).TotalSeconds
                $lblState.Text = "已断开 ${gone} 秒"
                if ($link) {
                    $state.step = 3; $state.backAt = Get-Date
                    Set-Step 3 "已插回，检查 USB 模式…" "如果 adb 正常会自动跳过这一步。" ""
                }
            }
            3 {
                $wait = [int]((Get-Date) - $state.backAt).TotalSeconds
                if ($adbState -eq "device") {
                    $state.step = 4
                    Set-Step 4 "USB 通道正常 OK" "等几秒，守护会自动重启投屏。" ""
                }
                elseif ($adbState -eq "unauthorized") {
                    Set-Step 3 "手机在等授权" "看手机屏幕：点「允许 USB 调试」。`r`n勾选「始终允许」更省事。" "已等待 ${wait}s"
                }
                else {
                    Set-Step 3 "请把 USB 模式改成「传输文件」" `
                        "手机上：下拉通知栏 → 点「正在通过 USB 充电 / 充电」`r`n→ 在选项里选「传输文件」(MTP)`r`n不要选「仅充电」，那个模式电脑连不进来。" `
                        "adb: $adbState  |  USB: 已连接`r`n已等待 ${wait}s"
                }
                if ($wait -gt 45 -and $adbState -ne "device") {
                    $lblHint.Text = "还是不通：拔掉重插一次，或检查开发者选项里「USB 调试」是否被关掉。"
                }
            }
            4 {
                if ($scrcpy) {
                    $state.step = 5
                    Set-Step 5 "投屏已恢复 OK" "试两下：Alt+F 切全屏、鼠标左键点手机界面。`r`n都正常就可以关掉本窗口。" "设备: 已连接`r`n投屏: 运行中"
                } else {
                    $wait = [int]((Get-Date) - $state.backAt).TotalSeconds
                    $lblState.Text = "等待投屏自动重启... ${wait}s"
                    if ($wait -gt 30) {
                        $lblHint.Text = "超过 30 秒没起来：守护可能被暂停（stop-pc），`r`n关掉窗口后我手动查。"
                    }
                }
            }
            5 {
                $lblState.Text = "设备: " + $(if ($adbState -eq "device") { "已连接" } else { $adbState }) + "`r`n投屏: " + $(if ($scrcpy) { "运行中" } else { "未运行" })
            }
        }
    } catch { }
})
$timer.Start()

$startPresent = $false
try {
    $o = (& $adb devices 2>&1) -join "`n"
    $startPresent = ($o -match "(?m)^\S+\s+device\s*$")
} catch {}
if (-not $startPresent) {
    $state.step = 2; $state.absentAt = Get-Date
    Set-Step 2 "手机当前未连接" "插上数据线即可，我会自动继续。" ""
} else {
    $state.step = 1
    Set-Step 1 "请拔掉手机数据线" "拔掉后什么也别做，等我自动检测。" "已连接，等待拔线…"
}

[void]$form.ShowDialog()
$timer.Stop()
try { $probe.Stop(); $probe.Dispose(); $rs.Close() } catch {}
