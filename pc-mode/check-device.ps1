# 换手机兼容性检测：对当前连接的手机做一次完整体检
# 用法: .\check-device.ps1
#       .\check-device.ps1 -Serial XXXXX     指定设备（多台时）
param([string]$Serial = "")
$ErrorActionPreference = "Continue"
$root = $PSScriptRoot
$localTemp = Join-Path $root "tmp"
if (-not (Test-Path $localTemp)) { New-Item -ItemType Directory -Path $localTemp -Force | Out-Null }
$env:TEMP = $localTemp
$env:TMP = $localTemp

$adb = Join-Path (Split-Path $root -Parent) "scrcpy-win64-v5.0.1\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }
if ($Serial) { $adbArgs = @("-s", $Serial) } else { $adbArgs = @("-d") }

function Sh([string]$cmd) { ((& $adb @adbArgs shell $cmd 2>&1) -join "`n").Trim() }

$ok = 0; $warn = 0; $bad = 0
function Line([string]$level, [string]$text, [string]$hint = "") {
    switch ($level) {
        "ok"   { Write-Host ("  [OK]   " + $text) -ForegroundColor Green; $script:ok++ }
        "warn" { Write-Host ("  [!!]   " + $text) -ForegroundColor Yellow; $script:warn++ }
        "bad"  { Write-Host ("  [XX]   " + $text) -ForegroundColor Red; $script:bad++ }
        default { Write-Host ("         " + $text) }
    }
    if ($hint) { Write-Host ("         -> " + $hint) -ForegroundColor DarkGray }
}

Write-Host ""
Write-Host "================ 手机主机 · 兼容性检测 ================" -ForegroundColor Cyan
Write-Host ""

# 1. 连接
$devs = ((& $adb devices 2>&1) -join "`n")
if ($devs -notmatch "(?m)^\S+\s+device\s*$") {
    Line bad "没有检测到已授权的手机"
    Line none "请用数据线连接，手机打开「开发者选项 → USB 调试」，弹窗点允许"
    exit 1
}
$serialNow = (($devs -split "`n") | Where-Object { $_ -match "^\S+\s+device\s*$" } | Select-Object -First 1) -split "\s+" | Select-Object -First 1
Line ok "设备已连接（序列号 $serialNow）"

# 2. 基本信息
$brand   = Sh "getprop ro.product.brand"
$model   = Sh "getprop ro.product.model"
$device  = Sh "getprop ro.product.device"
$android = Sh "getprop ro.build.version.release"
$sdk     = Sh "getprop ro.build.version.sdk"
$abi     = Sh "getprop ro.product.cpu.abi"
$miui    = Sh "getprop ro.miui.ui.version.name"

Write-Host ""
Write-Host "--- 设备信息 ---" -ForegroundColor Cyan
Line none "品牌型号   : $brand $model（$device）"
Line none "Android    : $android（SDK $sdk）"
Line none "CPU 架构   : $abi"
if ($miui) { Line none "系统 UI    : MIUI/HyperOS $miui" }

# 3. 版本门槛
Write-Host ""
Write-Host "--- 系统要求 ---" -ForegroundColor Cyan
$sdkNum = 0
[void][int]::TryParse($sdk, [ref]$sdkNum)
if ($sdkNum -ge 31) {
    Line ok "Android 12+ —— 支持虚拟屏（--new-display）"
} else {
    Line bad "Android $android 太老（需要 12+ / SDK 31+）" "虚拟屏功能不可用，本方案跑不了"
}
if ($sdkNum -ge 33) { Line ok "Android 13+ —— uhid 键盘/手柄直通可用" }
elseif ($sdkNum -ge 31) { Line warn "Android 12 —— uhid 可能不可用" "键盘改用 --keyboard=sdk" }

if ($abi -match "arm64") { Line ok "arm64 架构 —— Termux 标准包可用" }
else { Line bad "非 arm64（$abi）" "Termux 只有 arm64/arm 包，体验可能很差" }

# 4. 关键能力
Write-Host ""
Write-Host "--- 关键能力 ---" -ForegroundColor Cyan
$uhid = Sh "test -e /dev/uhid && echo yes || echo no"
if ($uhid -eq "yes") { Line ok "内核支持 uhid（键鼠直通）" }
else { Line warn "没有 /dev/uhid" "只能退化成 --keyboard=sdk" }

$inject = Sh "appops get com.android.shell INJECT_EVENTS 2>/dev/null | head -1"
if ($inject -match "allow") { Line ok "有 INJECT_EVENTS 权限（真触摸点击可用）" }
else {
    Line warn "没有 INJECT_EVENTS（鼠标点击会变成「指针」而不是「手指」）"
    if ($miui) { Line none "小米手机：开发者选项 → 「USB 调试（安全设置）」打开即可" }
    else { Line none "部分机型需要 root 或用 sdk 模式的鼠标" }
}

$writeSet = Sh "settings put global phonehost_probe 1; settings delete global phonehost_probe; echo done"
if ($writeSet -match "done") { Line ok "有 WRITE_SECURE_SETTINGS 权限" }
else { Line warn "没有 WRITE_SECURE_SETTINGS（部分自动设置会失败）" }

$sc = Sh "screencap -p /sdcard/.ph_probe.png >/dev/null 2>&1 && echo yes || echo no; rm -f /sdcard/.ph_probe.png"
if ($sc -eq "yes") { Line ok "截图可用" } else { Line warn "截图失败（不影响投屏）" }

# 5. 分辨率 / 密度 → 推荐虚拟屏
Write-Host ""
Write-Host "--- 屏幕与推荐虚拟屏 ---" -ForegroundColor Cyan
$size = Sh "wm size | grep -o -E '[0-9]+x[0-9]+' | head -1"
$dens = Sh "wm density | grep -o -E '[0-9]+' | head -1"
Line none "物理分辨率 : $size"
Line none "屏幕密度   : $dens dpi"
if ($size -match "^(\d+)x(\d+)$") {
    $pw = [int]$Matches[1]; $ph = [int]$Matches[2]
    $dpW = [int]($pw * 160 / [math]::Max(1, [int]$dens))
    Line none ("逻辑尺寸   : {0} x {1} dp" -f $dpW, [int]($ph * 160 / [math]::Max(1, [int]$dens)))
}

# 用电脑屏幕算推荐画布
Add-Type -AssemblyName System.Windows.Forms
$mon = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$aspect = $mon.Width / $mon.Height
$vdW = 2560
$vdH = [int][math]::Round($vdW / $aspect)
Line ok ("推荐虚拟屏 : {0}x{1} / 320dpi（按你的电脑 {2}x{3} 的比例算）" -f $vdW, $vdH, $mon.Width, $mon.Height)
Line none "开画布命令 : auto-start.ps1 -ForceW $vdW -ForceH $vdH -ForceDpi 320"

# 6. Termux 相关
Write-Host ""
Write-Host "--- Termux 套件 ---" -ForegroundColor Cyan
$pkgs = Sh "pm list packages | grep -i termux"
$hasTermux = $pkgs -match "package:com.termux$"
$hasX11    = $pkgs -match "com.termux.x11"
$hasApi    = $pkgs -match "com.termux.api"
$hasBoot   = $pkgs -match "com.termux.boot"
if ($hasTermux) { Line ok "Termux 已安装" } else { Line warn "Termux 未安装" "用安装包的「手机端」那步装，或手动装 termux.apk" }
if ($hasX11)    { Line ok "Termux:X11 已安装" } else { Line warn "Termux:X11 未安装（显示桌面必需）" }
if ($hasApi)    { Line ok "Termux:API 已安装" } else { Line warn "Termux:API 未安装（通知/电量读取要用）" }
if ($hasBoot)   { Line ok "Termux:Boot 已安装（开机自启）" } else { Line warn "Termux:Boot 未安装（开机自启要用）" }

# 7. 存储
Write-Host ""
Write-Host "--- 存储空间 ---" -ForegroundColor Cyan
$df = Sh "df -h /data | tail -1"
if ($df) {
    Line none $df
    if ($df -match "(\d+)%\s*/data") {
        $used = [int]$Matches[1]
        if ($df -match "(\d+)(?:\.\d+)?G\s+(\d+)%") {
            $freeGB = [int]$Matches[1]; $usedPct = [int]$Matches[2]
            if ($freeGB -lt 5) { Line bad ("剩余只有 {0} GB" -f $freeGB) "本方案需要 4~5 GB（桌面+浏览器+开发工具）" }
            elseif ($freeGB -lt 10) { Line warn ("剩余 {0} GB，够用但偏紧" -f $freeGB) "建议清一些空间" }
            else { Line ok ("剩余 {0} GB，够用（占用率 {1}%）" -f $freeGB, $usedPct) }
        }
    }
}

# 8. 汇总
Write-Host ""
Write-Host "================ 结论 ================" -ForegroundColor Cyan
Write-Host ("  OK: $ok    注意: $warn    不满足: $bad")
Write-Host ""
if ($bad -eq 0 -and $warn -le 2) {
    Write-Host "  ✔ 这台手机可以直接用本方案" -ForegroundColor Green
} elseif ($bad -eq 0) {
    Write-Host "  ✔ 能用，但有几处需要手动设置（看上面的提示）" -ForegroundColor Yellow
} else {
    Write-Host "  ✘ 有硬性条件不满足，见上面 [XX] 项" -ForegroundColor Red
}
Write-Host ""
Write-Host "下一步："
Write-Host "  1. 装手机端：双击桌面的「手机主机」→ 控制台，或用安装包里的 安装.bat 勾选手机端"
Write-Host "  2. 手机 Termux 里装环境（见 docs\安装与使用.md 第一节）"
Write-Host "  3. 控制台点 ② 开画布 → ③ 开 Linux"
Write-Host ""
