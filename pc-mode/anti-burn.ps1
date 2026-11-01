# 防烧屏：把手机物理屏幕真正熄掉（面板断电 = 零发光 = 不可能烧屏）
# 前提：你要看的东西跑在虚拟屏上（Linux 桌面 / 游戏虚拟屏），这样熄屏不影响它们
# 用法：
#   anti-burn.ps1 -On     熄屏（防烧屏）
#   anti-burn.ps1 -Off    唤醒屏幕
#   anti-burn.ps1 -Status 看当前状态
param([switch]$On, [switch]$Off, [switch]$Status, [switch]$Force)
$ErrorActionPreference = "Continue"
$root = $PSScriptRoot
$localTemp = Join-Path $root "tmp"
if (-not (Test-Path $localTemp)) { New-Item -ItemType Directory -Path $localTemp -Force | Out-Null }
$env:TEMP = $localTemp
$env:TMP = $localTemp

$adb = Join-Path (Split-Path $root -Parent) "scrcpy-win64-v5.0.1\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }

function Get-ScrcpyKind {
    $cl = (Get-CimInstance Win32_Process -Filter "Name='scrcpy.exe'" -ErrorAction SilentlyContinue | Select-Object -First 1).CommandLine
    if (-not $cl) { return "none" }
    if ($cl -match '--new-display') { return "vd" }
    return "mirror"
}

function Screen-State {
    $out = ((& $adb -d shell "dumpsys display 2>/dev/null | grep -m1 mScreenState" 2>&1) -join "`n")
    $line = ($out -split "`n")[0]
    # 注意：adb 可能把 stderr 拼在后面（...DOZEFailed to write...），所以要按已知状态词匹配
    foreach ($tok in @('DOZE','OFF','ON','VR','UNKNOWN')) {
        if ($line -match ("mScreenState=" + $tok)) { return $tok }
    }
    return "unknown"
}

if ($Status -or (-not $On -and -not $Off)) {
    $st = Screen-State
    $dev = ((& $adb -d shell "getprop sys.usb.config" 2>&1) -join "").Trim()
    Write-Host "屏幕状态: $st   （OFF/DOZE = 已熄屏）"
    Write-Host "USB 模式: $dev"
    $vd = ((& $adb -d shell "dumpsys display | grep -o -E 'displayId [0-9]+'" 2>&1) -join " ")
    $nums = ([regex]::Matches($vd, 'displayId (\d+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique) -join ", "
    Write-Host "display 列表: $nums   （除 0 之外有编号 = 虚拟屏在工作）"
    if ($st -EQ 'OFF' -or $st -EQ 'DOZE') { Write-Host "防烧屏: 已开启" } else { Write-Host "防烧屏: 未开启" }
    return
}

if ($On) {
    $kind = Get-ScrcpyKind
    if ($kind -eq 'mirror' -and -not $Force) {
        Write-Host "✗ 当前是【手机镜像】模式，熄屏会把它一起弄黑"
        Write-Host ""
        Write-Host "  原因：手机镜像映射的就是物理屏本身，面板断电 = 镜像没有画面可抓。"
        Write-Host "        这是原理限制，不是 bug。"
        Write-Host ""
        Write-Host "  想要「防烧屏 + 电脑上还能看画面」，只能用虚拟屏内容："
        Write-Host "    · Linux 桌面：控制台 ② 开画布 → ③ 开 Linux"
        Write-Host "    · 游戏：mirror-game-vd.bat"
        Write-Host ""
        Write-Host "  如果你就是想熄屏（不看画面），加 -Force 强制执行。"
        exit 1
    }

    Write-Host "[1/3] 检查是否有虚拟屏在承载内容…"
    $vd = ((& $adb -d shell "dumpsys display | grep -o -E 'displayId [0-9]+'" 2>&1) -join " ")
    $nums = [regex]::Matches($vd, 'displayId (\d+)') | ForEach-Object { [int]$_.Groups[1].Value } | Where-Object { $_ -ne 0 } | Sort-Object -Unique
    if (-not $nums) {
        Write-Host "      ⚠ 没有虚拟屏：物理屏熄掉后，主屏上的 App 会被暂停（画面冻住）"
        Write-Host "        想让手机当主机用，先按 ② 开画布"
    } else {
        Write-Host ("      虚拟屏在: " + ($nums -join ", ") + " → 熄屏不影响它")
    }

    Write-Host "[2/3] 保持唤醒锁（熄屏后 CPU 不休眠）…"
    & $adb -d shell "run-as com.termux sh -c 'termux-wake-lock 2>/dev/null; echo ok'" 2>&1 | Out-Null

    Write-Host "[3/3] 熄灭物理屏幕…"
    & $adb -d shell "input keyevent 223" 2>&1 | Out-Null
    Start-Sleep -Seconds 2
    $st = Screen-State
    Write-Host ("      屏幕状态: " + $st)
    if ($st -eq 'OFF' -or $st -eq 'DOZE') {
        Write-Host "完成：面板已断电（零发光，不会烧屏）。要亮屏：anti-burn.ps1 -Off"
        Set-Content -Path (Join-Path $localTemp "anti-burn.on") -Value (Get-Date -Format 'HH:mm:ss') -Encoding ASCII
    } else {
        Write-Host "⚠ 没能熄屏（可能被锁屏/应用唤醒），可再试一次或直接按电源键"
    }
    return
}

if ($Off) {
    Write-Host "唤醒屏幕…"
    & $adb -d shell "input keyevent 224" 2>&1 | Out-Null
    Start-Sleep -Seconds 1
    & $adb -d shell "wm dismiss-keyguard" 2>&1 | Out-Null
    Start-Sleep -Seconds 1
    Write-Host ("      屏幕状态: " + (Screen-State))
    Remove-Item (Join-Path $localTemp "anti-burn.on") -ErrorAction SilentlyContinue
    Write-Host "已唤醒"
    return
}
