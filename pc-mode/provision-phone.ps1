# 手机端一键安装 / 卸载与适配（图形界面）
# 流程：检测设备 → 装 APK → 初始化 Termux → 换镜像源 → 装桌面环境 → 部署脚本 → 终端优化 → 自适应
# 用法：控制台点 ⑦ 装手机端；或直接运行本脚本
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
Add-Type -Name Dpi -Namespace Prov -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);'
try { [void][Prov.Dpi]::SetProcessDpiAwarenessContext([IntPtr](-4)) } catch {}
$sysDpi = 96
try { $g0 = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero); $sysDpi = $g0.DpiX; $g0.Dispose() } catch {}
$s = $sysDpi / 96.0
function S([double]$v) { [int][math]::Round($v * $s) }

# ================= 远端脚本片段（顶层定义，避免嵌套 here-string） =================
$SH_STOP_DESKTOP = @'
export HOME=/data/data/com.termux/files/home
export PREFIX=/data/data/com.termux/files/usr
export PATH=$PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$PREFIX/lib
for p in lxqt-panel lxqt-notificationd lxqt-powermanagement pcmanfm-qt openbox \
         xfce4-panel xfdesktop xfwm4 xfce4-session ibus-daemon pulseaudio \
         host-mode.sh notify-bridge.sh termux-x11; do
  pkill -9 -f "$p" 2>/dev/null
done
echo stopped
'@

$SH_REMOVE_SCRIPTS = @'
export HOME=/data/data/com.termux/files/home
export PATH=/data/data/com.termux/files/usr/bin:$PATH
for f in start-lxqt.sh apply-lxqt-look.sh apply-scale.sh host-mode.sh \
         notify-bridge.sh launcher.sh start-host.sh start-xfce.sh install-desktop.sh .desktop-kind; do
  rm -f "$HOME/$f" 2>/dev/null
done
rm -f "$HOME/.termux/boot/start-host.sh" 2>/dev/null
echo removed
'@

$SH_BENCH_MIRROR = @'
export PREFIX=/data/data/com.termux/files/usr
export PATH=$PREFIX/bin:$PATH
best=""; bestsp=0
for base in \
  "https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main" \
  "https://mirrors.ustc.edu.cn/termux/apt/termux-main" \
  "https://mirrors.aliyun.com/termux/apt/termux-main" \
  "https://packages-cf.termux.dev/apt/termux-main" ; do
  sp=$(curl -s -o /dev/null -w "%{speed_download}" --max-time 8 -r 0-1500000 "$base/dists/stable/main/binary-aarch64/Packages.gz" 2>/dev/null)
  sp=${sp%.*}; [ -z "$sp" ] && sp=0
  if [ "$sp" -gt "$bestsp" ]; then bestsp=$sp; best=$base; fi
done
echo "BEST=$best"
'@

$SH_PROGRESS = @'
export HOME=/data/data/com.termux/files/home
export PATH=/data/data/com.termux/files/usr/bin:$PATH
g=$(grep -c "^Get:" $HOME/p-install.log 2>/dev/null)
s=$(grep -c "^Setting up" $HOME/p-install.log 2>/dev/null)
d=0; grep -q "^===== DONE" $HOME/p-install.log 2>/dev/null && d=1
x=0; grep -q "INSTALL_EXIT=" $HOME/p-install.log 2>/dev/null && x=$(grep "INSTALL_EXIT=" $HOME/p-install.log | tail -1 | cut -d= -f2)
echo "GET=$g SET=$s DONE=$d EXIT=$x"
'@

$SH_IBUS_DEFAULT = @'
export HOME=/data/data/com.termux/files/home
export PREFIX=/data/data/com.termux/files/usr
export PATH=$PREFIX/bin:$PATH
export DISPLAY=:0 XDG_RUNTIME_DIR=$PREFIX/tmp
FP=$(pgrep -f ibus-daemon | head -1)
if [ -n "$FP" ]; then
  export DBUS_SESSION_BUS_ADDRESS=$(tr '\0' '\n' < /proc/$FP/environ | grep '^DBUS_SESSION_BUS_ADDRESS=' | cut -d= -f2-)
  ibus engine libpinyin >/dev/null 2>&1 && echo IBUS_OK
fi
'@

# ================= 界面 =================
$form = New-Object System.Windows.Forms.Form
$form.Text = "装手机端 · 一键安装与适配"
$form.ClientSize = New-Object System.Drawing.Size((S 660), (S 640))
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 246, 248)
$form.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)

$t1 = New-Object System.Windows.Forms.Label
$t1.Text = "装手机端"
$t1.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 15, [System.Drawing.FontStyle]::Bold)
$t1.Location = New-Object System.Drawing.Point((S 22), (S 16))
$t1.AutoSize = $true
$form.Controls.Add($t1)

$t2 = New-Object System.Windows.Forms.Label
$t2.Text = "手机插上数据线、开 USB 调试并点「允许」，然后点开始安装"
$t2.ForeColor = [System.Drawing.Color]::FromArgb(110, 110, 118)
$t2.Location = New-Object System.Drawing.Point((S 24), (S 54))
$t2.AutoSize = $true
$form.Controls.Add($t2)

$devBox = New-Object System.Windows.Forms.GroupBox
$devBox.Text = "设备"
$devBox.Location = New-Object System.Drawing.Point((S 24), (S 84))
$devBox.Size = New-Object System.Drawing.Size((S 612), (S 96))
$form.Controls.Add($devBox)

$devInfo = New-Object System.Windows.Forms.Label
$devInfo.Location = New-Object System.Drawing.Point((S 14), (S 22))
$devInfo.Size = New-Object System.Drawing.Size((S 470), (S 66))
$devInfo.Font = New-Object System.Drawing.Font("Consolas", 9)
$devInfo.Text = "（点「重新检测」读设备信息）"
$devBox.Controls.Add($devInfo)

$btnScan = New-Object System.Windows.Forms.Button
$btnScan.Text = "重新检测"
$btnScan.Location = New-Object System.Drawing.Point((S 492), (S 20))
$btnScan.Size = New-Object System.Drawing.Size((S 104), (S 28))
$devBox.Controls.Add($btnScan)

$gb = New-Object System.Windows.Forms.GroupBox
$gb.Text = "要装的内容"
$gb.Location = New-Object System.Drawing.Point((S 24), (S 190))
$gb.Size = New-Object System.Drawing.Size((S 612), (S 170))
$form.Controls.Add($gb)

function New-Cb([string]$text, [int]$y, [bool]$checked = $true, [string]$hint = "") {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = if ($hint) { "$text    $hint" } else { $text }
    $cb.Checked = $checked
    $cb.Location = New-Object System.Drawing.Point((S 16), (S $y))
    $cb.AutoSize = $true
    $gb.Controls.Add($cb)
    return $cb
}
$cbApk  = New-Cb "① 手机端 App（5 个 APK）"                       26  $true  "Termux / X11 / API / Boot / Widget"
$cbEnv  = New-Cb "② Termux 桌面环境（LXQt + 输入法 + 音频）"        54  $true  "约 1.6 GB，5~20 分钟"
$cbDepl = New-Cb "③ 桌面脚本 + 开机自启"                          82  $true  "start-lxqt.sh / host-mode.sh 等"
$cbTune = New-Cb "④ 终端优化（关额外按键条 / 中文输入 / 加速源）"   110 $true  ""
$cbApps = New-Cb "⑤ 浏览器和编辑器（Firefox + VS Code）"            138 $false "多约 550 MB"

$log = New-Object System.Windows.Forms.TextBox
$log.Multiline = $true
$log.ScrollBars = "Vertical"
$log.ReadOnly = $true
$log.BackColor = [System.Drawing.Color]::FromArgb(24, 26, 30)
$log.ForeColor = [System.Drawing.Color]::FromArgb(220, 220, 226)
$log.Font = New-Object System.Drawing.Font("Consolas", 8.5)
$log.Location = New-Object System.Drawing.Point((S 24), (S 372))
$log.Size = New-Object System.Drawing.Size((S 612), (S 190))
$form.Controls.Add($log)

$cbAuto = New-Object System.Windows.Forms.CheckBox
$cbAuto.Text = "装完后自动建画布 + 开 LXQt 桌面"
$cbAuto.Checked = $true
$cbAuto.Location = New-Object System.Drawing.Point((S 24), (S 574))
$cbAuto.AutoSize = $true
$form.Controls.Add($cbAuto)

$btnUninst = New-Object System.Windows.Forms.Button
$btnUninst.Text = "卸载手机端"
$btnUninst.Location = New-Object System.Drawing.Point((S 262), (S 596))
$btnUninst.Size = New-Object System.Drawing.Size((S 120), (S 34))
$form.Controls.Add($btnUninst)

$btnGo = New-Object System.Windows.Forms.Button
$btnGo.Text = "开始安装"
$btnGo.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 10, [System.Drawing.FontStyle]::Bold)
$btnGo.Location = New-Object System.Drawing.Point((S 392), (S 596))
$btnGo.Size = New-Object System.Drawing.Size((S 120), (S 34))
$form.Controls.Add($btnGo)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "关闭"
$btnClose.Location = New-Object System.Drawing.Point((S 522), (S 596))
$btnClose.Size = New-Object System.Drawing.Size((S 114), (S 34))
$form.Controls.Add($btnClose)
$btnClose.add_Click({ $form.Close() })

function L([string]$m) {
    $log.AppendText("[" + (Get-Date -Format 'HH:mm:ss') + "] $m`r`n")
    $log.SelectionStart = $log.TextLength
    $log.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}
function Pump([int]$ms) {
    $end = (Get-Date).AddMilliseconds($ms)
    while ((Get-Date) -lt $end) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 50 }
}
function Sh([string]$cmd) { ((& $adb -d shell $cmd 2>&1) -join "`n").Trim() }
function ShRun([string]$script) {
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($script))
    return ((& $adb -d shell "run-as com.termux sh -c 'echo $b64 | base64 -d > files/home/.p.sh; sh files/home/.p.sh'" 2>&1) -join "`n").Trim()
}

$script:devOk = $false
$script:sdkNum = 0
function Refresh-Device {
    $devInfo.Text = "检测中…"
    [System.Windows.Forms.Application]::DoEvents()
    $out = ((& $adb devices 2>&1) -join "`n")
    if ($out -match "(?m)^\S+\s+unauthorized") {
        $devInfo.Text = "手机上弹了「允许 USB 调试吗？」→ 请点允许（勾上始终允许）`r`n没弹窗就：解锁屏幕 → 通知栏切「传输文件」→ 重新插线"
        $script:devOk = $false
        return
    }
    if ($out -notmatch "(?m)^\S+\s+device\s*$") {
        $devInfo.Text = "未检测到手机`r`n请：数据线连电脑 → 开发者选项 → USB 调试 → 手机弹窗点允许"
        $script:devOk = $false
        return
    }
    $brand = Sh "getprop ro.product.brand"
    $model = Sh "getprop ro.product.model"
    $sdk   = Sh "getprop ro.build.version.sdk"
    $and   = Sh "getprop ro.build.version.release"
    $abi   = Sh "getprop ro.product.cpu.abi"
    $uhid  = Sh "test -e /dev/uhid && echo yes || echo no"
    $inject = Sh "appops get com.android.shell INJECT_EVENTS 2>/dev/null | head -1"
    $injTxt = if ($inject -match "allow") { "OK" } else { "缺（开发者选项 → USB 调试（安全设置））" }
    $devInfo.Text = ("{0} {1}  ·  Android {2} (SDK {3})  ·  {4}`r`nuhid: {5}    真触摸: {6}" -f $brand, $model, $and, $sdk, $abi, $uhid, $injTxt)
    $script:devOk = $true
    $script:sdkNum = 0
    [void][int]::TryParse($sdk, [ref]$script:sdkNum)
}
$btnScan.add_Click({ Refresh-Device })

# ================= 安装 =================
$btnGo.add_Click({
    $btnGo.Enabled = $false
    Refresh-Device
    if (-not $script:devOk) { L "设备未就绪，先处理上面的提示"; $btnGo.Enabled = $true; return }
    if ($script:sdkNum -lt 31) { L "!! Android 版本太老（需要 12+），虚拟屏用不了" }
    L "=== 开始安装手机端 ==="

    if ($cbApk.Checked) {
        L "① 安装手机端 App"
        $need = @(
            @{ pkg="com.termux";        apk="termux.apk";        name="Termux" },
            @{ pkg="com.termux.x11";    apk="termux-x11.apk";    name="Termux:X11" },
            @{ pkg="com.termux.api";    apk="termux-api.apk";    name="Termux:API" },
            @{ pkg="com.termux.boot";   apk="termux-boot.apk";   name="Termux:Boot" },
            @{ pkg="com.termux.widget"; apk="termux-widget.apk"; name="Termux:Widget" }
        )
        foreach ($n in $need) {
            $inst = Sh "pm list packages $($n.pkg)"
            if ($inst -match [regex]::Escape($n.pkg)) { L ("   · 已装 " + $n.name); continue }
            $f = Join-Path $root $n.apk
            if (-not (Test-Path $f)) { L ("   ! 缺文件 " + $n.apk); continue }
            L ("   装 " + $n.name + " …")
            $done = $false
            for ($i = 1; $i -le 3 -and -not $done; $i++) {
                $r = ((& $adb -d install -r $f 2>&1) -join " ")
                if ($r -match "Success") { $done = $true } else { Pump 2000 }
            }
            if ($done) { L ("   OK " + $n.name) } else { L ("   XX " + $n.name + "（手机上点允许后重试）") }
        }
    }

    if ($cbEnv.Checked) {
        L "② 初始化 Termux"
        Sh "am start -n com.termux/.HomeActivity" | Out-Null
        $ready = $false
        for ($i = 0; $i -lt 12 -and -not $ready; $i++) {
            Pump 3000
            $r = Sh "run-as com.termux sh -c 'test -x files/usr/bin/pkg && echo READY || echo WAIT'"
            if ($r -match "READY") { $ready = $true }
        }
        if (-not $ready) {
            L "   ! Termux 没初始化成功：手动打开一次 Termux（看到 $ 提示符）再点开始安装"
        } else {
            L "   OK Termux 已就绪"

            L "   测速选最快的镜像源…"
            $bench = ShRun $SH_BENCH_MIRROR
            $mirror = "https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main"
            if ($bench -match "BEST=(\S+)") { $mirror = $Matches[1] }
            $x11 = $mirror -replace "termux-main", "termux-x11"
            L ("   选中的源: " + $mirror)

            $setSrc = @"
export PREFIX=/data/data/com.termux/files/usr
export PATH=`$PREFIX/bin:`$PATH
sed -i 's|https://[^ ]*/apt/termux-main|$mirror|g' `$PREFIX/etc/apt/sources.list
for f in `$PREFIX/etc/apt/sources.list.d/*.list; do
  [ -f "`$f" ] || continue
  sed -i 's|https://[^ ]*/apt/termux-x11|$x11|g' "`$f"
done
echo SRC_OK
"@
            $r = ShRun $setSrc
            if ($r -match "SRC_OK") { L "   源已写入" } else { L "   源写入可能失败（继续）" }

            L "   装 x11 仓库 + 更新索引…"
            ShRun @'
export PREFIX=/data/data/com.termux/files/usr
export PATH=$PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$PREFIX/lib
export DEBIAN_FRONTEND=noninteractive
apt-get -y -o Dpkg::Options::=--force-confold install x11-repo > /dev/null 2>&1
apt-get update > /dev/null 2>&1
echo UPDATE_DONE
'@ | Out-Null
            L "   索引已更新"

            L "   开始装桌面环境（最慢的一步，可以先离开）"
            $pkgs = "termux-x11-nightly lxqt openbox dbus xdotool procps ibus ibus-libpinyin pulseaudio"
            if ($cbApps.Checked) { $pkgs += " firefox code-oss mpv flameshot lximage-qt" }

            $installer = @"
#!/data/data/com.termux/files/usr/bin/bash
export HOME=/data/data/com.termux/files/home
export PREFIX=/data/data/com.termux/files/usr
export PATH=`$PREFIX/bin:`$PATH
export LD_LIBRARY_PATH=`$PREFIX/lib
export DEBIAN_FRONTEND=noninteractive
OPT="-y -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef"
P=`$PREFIX/var/lib/dpkg/info/xdg-utils.postinst
if [ -f "`$P" ]; then
  cp "`$P" "`$P.bak" 2>/dev/null
  printf '#!/data/data/com.termux/files/usr/bin/sh\nexit 0\n' > "`$P"
  chmod +x "`$P"
fi
{
  echo "===== START `$(date) ====="
  apt-get `$OPT install $pkgs
  echo "INSTALL_EXIT=`$?"
  echo "===== DONE `$(date) ====="
} > `$HOME/p-install.log 2>&1
"@
            $b64i = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($installer))
            Sh "echo $b64i | base64 -d > files/home/install-desktop.sh; chmod +x files/home/install-desktop.sh" | Out-Null
            Sh "setsid nohup bash files/home/install-desktop.sh > /dev/null 2>&1 < /dev/null & echo started" | Out-Null

            $lastGet = -1; $lastSet = -1
            for ($i = 0; $i -lt 400; $i++) {
                Pump 3000
                $prog = ShRun $SH_PROGRESS
                if ($prog -match "GET=(\d+) SET=(\d+) DONE=(\d+) EXIT=(\d+)") {
                    $gN = [int]$Matches[1]; $sN = [int]$Matches[2]; $dN = [int]$Matches[3]; $xN = [int]$Matches[4]
                    if ($gN -ne $lastGet -or $sN -ne $lastSet) {
                        L ("   下载 {0} 个 · 配置 {1} 个包" -f $gN, $sN)
                        $lastGet = $gN; $lastSet = $sN
                    }
                    if ($dN -eq 1) {
                        if ($xN -eq 0) { L "   OK 桌面环境装好了" }
                        else { L ("   ! 安装有报错（exit {0}），日志：手机 ~/p-install.log" -f $xN) }
                        break
                    }
                }
            }
        }
    }

    if ($cbDepl.Checked) {
        L "③ 部署桌面脚本"
        $scripts = @("phone\start-lxqt.sh","phone\apply-lxqt-look.sh","phone\apply-scale.sh","phone\host-mode.sh",
                     "phone\notify-bridge.sh","phone\launcher.sh","phone\start-host.sh","start-xfce.sh")
        foreach ($rel in $scripts) {
            $src = Join-Path $root $rel
            if (-not (Test-Path $src)) { L ("   ! 缺 " + $rel); continue }
            $name = Split-Path $src -Leaf
            $b = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText($src, [Text.Encoding]::UTF8)))
            Sh "echo $b | base64 -d > files/home/$name; chmod +x files/home/$name" | Out-Null
            L ("   OK " + $name)
        }
        Sh "mkdir -p files/home/.termux/boot; cp files/home/start-host.sh files/home/.termux/boot/start-host.sh 2>/dev/null; chmod +x files/home/.termux/boot/start-host.sh 2>/dev/null" | Out-Null
        L "   OK 开机自启"
    }

    if ($cbTune.Checked) {
        L "④ 终端优化"
        $xml = '<?xml version="1.0" encoding="utf-8" standalone="yes" ?><map><boolean name="show_extra_keys" value="false" /></map>'
        $b64x = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($xml))
        $inner = "mkdir -p /data/data/com.termux.x11/shared_prefs; echo $b64x | base64 -d > /data/data/com.termux.x11/shared_prefs/com.termux.x11_preferences.xml; echo ok"
        $innerB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($inner))
        $r = ((& $adb -d shell "run-as com.termux.x11 sh -c 'echo $innerB64 | base64 -d > files/.p.sh; sh files/.p.sh'" 2>&1) -join " ")
        if ($r -match "ok") { L "   OK 已关 Termux:X11 额外按键条" } else { L "   · 额外按键条跳过" }
        ShRun $SH_IBUS_DEFAULT | Out-Null
        L "   OK 中文输入法 = 拼音"
        Sh "run-as com.termux sh -c 'echo lxqt > files/home/.desktop-kind'" | Out-Null
        L "   OK 默认桌面 = LXQt"
    }

    L "⑤ 自适应分辨率"
    try {
        $mon = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $aspect = $mon.Width / $mon.Height
        $vdW = 2560
        $vdH = [int][math]::Round($vdW / $aspect)
        L ("   电脑屏幕 {0}x{1} → 推荐虚拟屏 {2}x{3} / 320dpi" -f $mon.Width, $mon.Height, $vdW, $vdH)
    } catch { L "   · 屏幕信息读不到，用默认 2560x1600" }

    L "=== 安装完成 ==="
    L "下一步：控制台 ② 开画布 → ③ 开 Linux"

    if ($cbAuto.Checked) {
        L "正在建画布并开桌面…"
        $as = Join-Path $root "auto-start.ps1"
        if (Test-Path $as) {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $as 2>&1 | ForEach-Object { if ("$_".Trim()) { L ("   " + "$_".Trim()) } }
        }
        $lx = Join-Path $root "start-lxqt.ps1"
        if (Test-Path $lx) {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $lx 2>&1 | ForEach-Object { if ("$_".Trim()) { L ("   " + "$_".Trim()) } }
        }
    }
    $btnGo.Enabled = $true
})

# ================= 卸载 =================
function Uninstall-Phone {
    Refresh-Device
    if (-not $script:devOk) { L "设备未就绪，无法卸载"; return }

    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "卸载手机端"
    $dlg.ClientSize = New-Object System.Drawing.Size((S 440), (S 310))
    $dlg.StartPosition = "CenterParent"
    $dlg.FormBorderStyle = "FixedSingle"
    $dlg.MaximizeBox = $false
    $dlg.BackColor = [System.Drawing.Color]::FromArgb(245, 246, 248)
    $dlg.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)

    $dt = New-Object System.Windows.Forms.Label
    $dt.Text = "选择要卸载的内容"
    $dt.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 12, [System.Drawing.FontStyle]::Bold)
    $dt.Location = New-Object System.Drawing.Point((S 18), (S 14))
    $dt.AutoSize = $true
    $dlg.Controls.Add($dt)

    $dcbRun = New-Object System.Windows.Forms.CheckBox
    $dcbRun.Text = "① 停止桌面进程"
    $dcbRun.Checked = $true
    $dcbRun.Location = New-Object System.Drawing.Point((S 18), (S 46))
    $dcbRun.AutoSize = $true
    $dlg.Controls.Add($dcbRun)

    $dcbScr = New-Object System.Windows.Forms.CheckBox
    $dcbScr.Text = "② 删除手机端脚本"
    $dcbScr.Checked = $true
    $dcbScr.Location = New-Object System.Drawing.Point((S 18), (S 96))
    $dcbScr.AutoSize = $true
    $dlg.Controls.Add($dcbScr)

    $dcbApk = New-Object System.Windows.Forms.CheckBox
    $dcbApk.Text = "③ 卸载 5 个 APK（Termux 全家桶）"
    $dcbApk.Checked = $false
    $dcbApk.Location = New-Object System.Drawing.Point((S 18), (S 146))
    $dcbApk.AutoSize = $true
    $dlg.Controls.Add($dcbApk)

    $h1 = New-Object System.Windows.Forms.Label
    $h1.Text = "关掉 LXQt / X / 输入法 / 音频，已装的软件保留"
    $h1.ForeColor = [System.Drawing.Color]::FromArgb(120, 120, 128)
    $h1.Location = New-Object System.Drawing.Point((S 36), (S 68))
    $h1.AutoSize = $true
    $dlg.Controls.Add($h1)

    $h2 = New-Object System.Windows.Forms.Label
    $h2.Text = "start-lxqt.sh / host-mode.sh 等 + 开机自启"
    $h2.ForeColor = [System.Drawing.Color]::FromArgb(120, 120, 128)
    $h2.Location = New-Object System.Drawing.Point((S 36), (S 118))
    $h2.AutoSize = $true
    $dlg.Controls.Add($h2)

    $h3 = New-Object System.Windows.Forms.Label
    $h3.Text = "会连 Termux 里的 Linux 一起删掉，装回来要重来"
    $h3.ForeColor = [System.Drawing.Color]::FromArgb(190, 80, 60)
    $h3.Location = New-Object System.Drawing.Point((S 36), (S 168))
    $h3.AutoSize = $true
    $dlg.Controls.Add($h3)

    $okBtn = New-Object System.Windows.Forms.Button
    $okBtn.Text = "开始卸载"
    $okBtn.Location = New-Object System.Drawing.Point((S 206), (S 250))
    $okBtn.Size = New-Object System.Drawing.Size((S 110), (S 32))
    $dlg.Controls.Add($okBtn)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = "取消"
    $cancel.Location = New-Object System.Drawing.Point((S 324), (S 250))
    $cancel.Size = New-Object System.Drawing.Size((S 96), (S 32))
    $dlg.Controls.Add($cancel)
    $cancel.add_Click({ $dlg.Close() })

    $okBtn.add_Click({
        $dlg.Enabled = $false
        L "=== 开始卸载手机端 ==="
        if ($dcbRun.Checked) {
            L "① 停止桌面进程"
            ShRun $SH_STOP_DESKTOP | Out-Null
            Sh "am force-stop com.termux.x11" | Out-Null
            L "   OK 已停止"
        }
        if ($dcbScr.Checked) {
            L "② 删除手机端脚本"
            ShRun $SH_REMOVE_SCRIPTS | Out-Null
            L "   OK 已删除"
        }
        if ($dcbApk.Checked) {
            L "③ 卸载 5 个 APK"
            foreach ($pk in @("com.termux.x11","com.termux.api","com.termux.boot","com.termux.widget","com.termux")) {
                $r = ((& $adb -d uninstall $pk 2>&1) -join " ")
                if ($r -match "Success") { L ("   OK " + $pk) }
                elseif ($r -match "not installed") { L ("   · " + $pk + " 本来就没装") }
                else { L ("   ! " + $pk + " 失败") }
            }
        }
        L "=== 卸载完成 ==="
        $dlg.Close()
    })
    [void]$dlg.ShowDialog()
}
$btnUninst.add_Click({ Uninstall-Phone })

$form.Add_Shown({ Refresh-Device })
[void]$form.ShowDialog()
