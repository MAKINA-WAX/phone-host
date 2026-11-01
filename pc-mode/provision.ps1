# 一键补齐环境：缺什么装什么（装 APK → 初始化 Termux → 装 XFCE → 配置 → 防杀后台）
# 用法: provision.ps1
$ErrorActionPreference = "Continue"

$localTemp = Join-Path $PSScriptRoot "tmp"
if (-not (Test-Path $localTemp)) { New-Item -ItemType Directory -Path $localTemp -Force | Out-Null }
$env:TEMP = $localTemp
$env:TMP = $localTemp

$root = Split-Path $PSScriptRoot -Parent
$adb = Join-Path $root "scrcpy-win64-v5.0.1\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }

function Run($cmd) { (& $cmd 2>&1) -join "`n" }
function Step($t) { Write-Host "`n== $t ==" -ForegroundColor Cyan }

# 0. 设备
Step "0. 检查设备"
$devs = (Run { & $adb devices }) -split "`n" | Where-Object { $_ -match "\s+device$" }
if ($devs.Count -eq 0) { Write-Host "[FAIL] 没检测到手机：插数据线 + 打开 USB 调试" -ForegroundColor Red; exit 1 }
Write-Host "  设备: $((($devs -join ' / ').Trim()))"

# 1. APK
Step "1. 安装手机端 App"
$need = @(
    @{ pkg = "com.termux";       apk = "termux.apk";        name = "Termux" },
    @{ pkg = "com.termux.x11";   apk = "termux-x11.apk";    name = "Termux:X11" },
    @{ pkg = "com.termux.widget"; apk = "termux-widget.apk"; name = "Termux:Widget（可选）" }
)
foreach ($n in $need) {
    $installed = (Run { & $adb -d shell "pm list packages $($n.pkg)" }) -match $n.pkg
    if ($installed) { Write-Host "  已装: $($n.name)"; continue }
    $apk = Join-Path $PSScriptRoot $n.apk
    if (-not (Test-Path $apk)) { Write-Host "  [SKIP] 缺 $($n.apk)（可用 dl-termux.js 重新下载）" -ForegroundColor Yellow; continue }
    $done = $false
    for ($i = 1; $i -le 3 -and -not $done; $i++) {
        $out = Run { & $adb -d install -r $apk }
        if ($out -match "Success") { $done = $true }
        else { Write-Host "  第 $i 次失败，重试（手机上若弹确认请点允许）…" -ForegroundColor Yellow; Start-Sleep -Seconds 3 }
    }
    if ($done) { Write-Host "  [OK] 安装 $($n.name)" } else { Write-Host "  [FAIL] $($n.name) 安装失败" -ForegroundColor Red }
}

# 2. Termux 首次初始化
Step "2. Termux 初始化"
$probe = @'
ls /data/data/com.termux/files/usr/bin/bash >/dev/null 2>&1 && echo BOOT_OK || echo BOOT_NO
'@
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($probe))
$r = Run { & $adb -d shell "run-as com.termux sh -c 'echo $b64 | base64 -d > /data/data/com.termux/files/home/.p.sh; sh /data/data/com.termux/files/home/.p.sh'" }
if ($r -match "BOOT_NO") {
    Write-Host "  首次启动 Termux 解压 bootstrap…"
    Run { & $adb -d shell "am start -n com.termux/.app.TermuxActivity" } | Out-Null
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 2
        $r = Run { & $adb -d shell "run-as com.termux sh -c 'echo $b64 | base64 -d > /data/data/com.termux/files/home/.p.sh; sh /data/data/com.termux/files/home/.p.sh'" }
        if ($r -match "BOOT_OK") { break }
    }
}
if ($r -match "BOOT_OK") { Write-Host "  [OK] bootstrap 就绪" } else { Write-Host "  [FAIL] Termux 未初始化" -ForegroundColor Red }

# 3. allow-external-apps
Step "3. 允许外部调用（Termux:Widget 需要）"
$props = "allow-external-apps=true`n"
$pb64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($props))
Run { & $adb -d shell "run-as com.termux sh -c 'mkdir -p files/.termux; echo $pb64 | base64 -d > files/.termux/termux.properties'" } | Out-Null
Write-Host "  [OK] termux.properties 已写"

# 4. XFCE
Step "4. X11 + XFCE 桌面"
$xfceProbe = @'
ls /data/data/com.termux/files/usr/bin/startxfce4 >/dev/null 2>&1 && echo XFCE_OK || echo XFCE_NO
'@
$xb64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($xfceProbe))
$xr = Run { & $adb -d shell "run-as com.termux sh -c 'echo $xb64 | base64 -d > /data/data/com.termux/files/home/.x.sh; sh /data/data/com.termux/files/home/.x.sh'" }
if ($xr -match "XFCE_OK") {
    Write-Host "  已装 XFCE，跳过"
} else {
    Write-Host "  开始安装（约 500MB，走清华镜像，可能需要几分钟）…"
    $setup = Get-Content (Join-Path $PSScriptRoot "setup-termux.sh") -Raw
    $sb64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($setup))
    Run { & $adb -d shell "run-as com.termux sh -c 'echo $sb64 | base64 -d > files/home/setup.sh; chmod +x files/home/setup.sh'" } | Out-Null
    $remote = @'
run-as com.termux sh -c 'export HOME=/data/data/com.termux/files/home; export PATH=/data/data/com.termux/files/usr/bin:$PATH; export LD_LIBRARY_PATH=/data/data/com.termux/files/usr/lib; bash $HOME/setup.sh 2>&1 | tail -5'
'@
    $out = Run { & $adb -d shell $remote }
    if ($out -match "SETUP_OK") { Write-Host "  [OK] XFCE 安装完成" } else { Write-Host "  [FAIL] 安装未完成，看上面日志" -ForegroundColor Red }
}

# 5. Termux:X11 偏好（关掉虚拟按键条 + 全屏）
Step "5. Termux:X11 偏好"
$prefs = @"
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <boolean name="showAdditionalKbd" value="false" />
    <boolean name="fullscreen" value="true" />
    <boolean name="pauseKeyInterceptingWithEsc" value="true" />
    <boolean name="preferScancodes" value="true" />
    <boolean name="displayStretch" value="true" />
    <boolean name="adjustResolution" value="true" />
</map>
"@
$prefB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($prefs))
Run { & $adb -d shell "am force-stop com.termux.x11" } | Out-Null
Run { & $adb -d shell "run-as com.termux.x11 sh -c 'mkdir -p shared_prefs; echo $prefB64 | base64 -d > shared_prefs/com.termux.x11_preferences.xml'" } | Out-Null
Write-Host "  [OK] 已关掉额外按键条并全屏"

# 6. 防杀后台
Step "6. 防杀后台"
Run { & $adb -d shell "dumpsys deviceidle whitelist +com.termux" } | Out-Null
Run { & $adb -d shell "dumpsys deviceidle whitelist +com.termux.x11" } | Out-Null
Run { & $adb -d shell "am set-standby-bucket com.termux active" } | Out-Null
Run { & $adb -d shell "am set-standby-bucket com.termux.x11 active" } | Out-Null
Run { & $adb -d shell "cmd appops set com.termux RUN_IN_BACKGROUND allow" } | Out-Null
Run { & $adb -d shell "cmd appops set com.termux RUN_ANY_IN_BACKGROUND allow" } | Out-Null
Write-Host "  [OK] Doze 白名单 + 活跃桶 + 后台权限"

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "harden.ps1")
Write-Host "`n环境准备完成。下一步：" -ForegroundColor Green
Write-Host "  doctor.ps1      再检测一遍"
Write-Host "  2-start-pc.bat  开画布（自适应分辨率）"
Write-Host "  5-xfce.bat      开 Linux 桌面"
