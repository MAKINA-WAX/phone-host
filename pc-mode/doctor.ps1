# 环境检测：投屏 + Linux 环境是否就绪（只检查，不改动）
# 用法: doctor.ps1
$ErrorActionPreference = "Continue"

$localTemp = Join-Path $PSScriptRoot "tmp"
if (-not (Test-Path $localTemp)) { New-Item -ItemType Directory -Path $localTemp -Force | Out-Null }
$env:TEMP = $localTemp
$env:TMP = $localTemp

$scrcpyDir = Join-Path (Split-Path $PSScriptRoot -Parent) "scrcpy-win64-v5.0.1"
$adb = Join-Path $scrcpyDir "adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }
$scrcpy = Join-Path $scrcpyDir "scrcpy.exe"

$ok = 0; $bad = 0; $warn = 0
$rows = @()
function Check($name, $good, $detail) {
    $mark = if ($good) { "[ OK ]" } else { "[FAIL]" }
    if ($good) { $script:ok++ } else { $script:bad++ }
    $script:rows += [pscustomobject]@{ 状态 = $mark; 项目 = $name; 详情 = $detail }
}
function Warn($name, $detail) {
    $script:warn++
    $script:rows += [pscustomobject]@{ 状态 = "[WARN]"; 项目 = $name; 详情 = $detail }
}
function Run($cmd) { (& $cmd 2>&1) -join "`n" }

Write-Host "==== 手机主机 环境检测 ====" -ForegroundColor Cyan

# 1. 工具链
Check "scrcpy.exe" (Test-Path $scrcpy) $(if (Test-Path $scrcpy) { $scrcpy } else { "缺少 scrcpy-win64 目录" })
$v = if (Test-Path $scrcpy) { (Run { & $scrcpy --version }) -split "`n" | Select-Object -First 1 } else { "" }
if ($v) { Check "scrcpy 版本" ($v -match "scrcpy") $v.Trim() }

# 2. 设备
$devs = (Run { & $adb devices }) -split "`n" | Where-Object { $_ -match "\s+device$" }
Check "USB 设备连接" ($devs.Count -gt 0) $(if ($devs.Count) { ($devs -join " / ").Trim() } else { "插数据线 + 打开 USB 调试" })

if ($devs.Count -gt 0) {
    $model = (Run { & $adb -d shell getprop ro.product.model }).Trim()
    $sdk = (Run { & $adb -d shell getprop ro.build.version.sdk }).Trim()
    $rel = (Run { & $adb -d shell getprop ro.build.version.release }).Trim()
    Check "机型 / 系统" ($model -and $sdk) "$model  Android $rel (SDK $sdk)"

    # 3. 电脑显示器（DPI 感知，避免把逻辑分辨率当物理）
    Add-Type -Name Mon2 -Namespace Doctor -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
public delegate bool EnumProc(IntPtr h, IntPtr hdc, IntPtr r, IntPtr d);
[DllImport("user32.dll")] public static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr r, EnumProc p, IntPtr d);
[DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern bool GetMonitorInfo(IntPtr h, ref MI i);
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int l,t,r,b; }
[StructLayout(LayoutKind.Sequential)] public struct MI { public int cb; public RECT mon; public RECT work; public uint flags; }
'@
    [void][Doctor.Mon2]::SetProcessDpiAwarenessContext([IntPtr](-4))
    $mons = New-Object System.Collections.ArrayList
    $cb = [Doctor.Mon2+EnumProc]{
        param($h, $hdc, $r, $d)
        $mi = New-Object Doctor.Mon2+MI
        $mi.cb = [System.Runtime.InteropServices.Marshal]::SizeOf($mi)
        if ([Doctor.Mon2]::GetMonitorInfo($h, [ref]$mi)) {
            [void]$mons.Add(("{0}x{1}{2}" -f ($mi.mon.r - $mi.mon.l), ($mi.mon.b - $mi.mon.t), $(if (($mi.flags -band 1)) { " (主屏)" } else { "" })))
        }
        return $true
    }
    [void][Doctor.Mon2]::EnumDisplayMonitors([IntPtr]::Zero, [IntPtr]::Zero, $cb, [IntPtr]::Zero)
    Check "电脑显示器（物理像素）" ($mons.Count -gt 0) ($mons -join " + ")

    # 4. 手机端组件
    $pkgs = Run { & $adb -d shell "pm list packages" }
    Check "Termux 已安装" ($pkgs -match "package:com\.termux\b") "提供 Linux 用户空间"
    Check "Termux:X11 已安装" ($pkgs -match "package:com\.termux\.x11") "把 X11 桌面上屏"
    Warn "Termux:Widget（可选）" $(if ($pkgs -match "package:com\.termux\.widget") { "已装：手机桌面可加一键开 Linux 按钮" } else { "未装：不影响主机模式" })
    if ($pkgs -match "package:com\.farmerbb\.taskbar") { Warn "Taskbar 仍在" "PC 风格外壳，建议卸载" } else { Check "无 PC 风格残留" $true "Taskbar 已移除" }

    # 5. Termux 内部（需要 debug 构建才可用 run-as）
    $probeB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(@'
ls /data/data/com.termux/files/usr/bin/bash >/dev/null 2>&1 && echo BOOT_OK || echo BOOT_NO
ls /data/data/com.termux/files/usr/bin/startxfce4 >/dev/null 2>&1 && echo XFCE_OK || echo XFCE_NO
ls /data/data/com.termux/files/usr/bin/termux-x11 >/dev/null 2>&1 && echo X11_OK || echo X11_NO
ls /data/data/com.termux/files/usr/bin/sshd >/dev/null 2>&1 && echo SSH_OK || echo SSH_NO
'@))
    $r = Run { & $adb -d shell "run-as com.termux sh -c 'echo $probeB64 | base64 -d > /data/data/com.termux/files/home/.probe.sh; sh /data/data/com.termux/files/home/.probe.sh'" }
    Check "Termux 可用 run-as（debug 构建）" ($r -match "BOOT_OK" -or $r -match "XFCE_OK") $(if ($r -match "BOOT_NO") { "未完成首次初始化：打开一次 Termux" } else { "已初始化" })
    Check "XFCE 桌面已安装" ($r -match "XFCE_OK") $(if ($r -match "XFCE_OK") { "xfce4 4.20" } else { "缺：跑 provision.bat" })
    Check "termux-x11 已安装" ($r -match "X11_OK") $(if ($r -match "X11_OK") { "X11 服务就绪" } else { "缺：跑 provision.bat" })
    Warn "openssh（可选）" $(if ($r -match "SSH_OK") { "已装：可纯 SSH 无头使用" } else { "未装：无头模式需要它" })

    # 6. 防杀后台
    $wl = Run { & $adb -d shell "dumpsys deviceidle whitelist" }
    Check "Termux 在 Doze 白名单" ($wl -match "com\.termux,") "防后台被杀"
    $bucket = (Run { & $adb -d shell "am get-standby-bucket com.termux" }).Trim()
    Check "Termux 待机桶 = ACTIVE" ($bucket -eq "5") "当前值 $bucket（5=ACTIVE）"

    # 7. 运行态
    $disps = (Run { & $adb -d shell "dumpsys display | grep -o -E 'displayId [0-9]+'" }) -split "`n"
    $ids = @()
    foreach ($m in [regex]::Matches(($disps -join "`n"), 'displayId (\d+)')) { $ids += [int]$m.Groups[1].Value }
    $ids = $ids | Sort-Object -Unique
    $hasVd = ($ids | Where-Object { $_ -ne 0 }).Count -gt 0
    $screenText = (($ids | ForEach-Object { "displayId $_" }) -join " ")
    if ($hasVd) { $screenText = $screenText + "  （已有虚拟屏在跑）" } else { $screenText = $screenText + "  （只有手机本机屏）" }
    Warn "当前屏幕" $screenText

    $procList = Run { & $adb -d shell "ps -A -o NAME | grep -E 'termux-x11|xfce4-session' | sort -u" }
    $procText = (($procList -split "`n") | Where-Object { $_.Trim() }) -join ", "
    if (-not $procText) { $procText = "未运行（5-xfce.bat 启动）" }
    Warn "Linux 桌面进程" $procText
}

$rows | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
Write-Host ("汇总: 通过 {0} / 警告 {1} / 失败 {2}" -f $ok, $warn, $bad) -ForegroundColor $(if ($bad -eq 0) { "Green" } else { "Yellow" })
if ($bad -gt 0) { Write-Host "有失败项 → 跑 setup.bat 自动补齐环境" -ForegroundColor Yellow }