# 下载本项目需要的二进制资源（仓库里不存这些）
#   .\download-assets.ps1            下载全部
#   .\download-assets.ps1 -Scrcpy    只下 scrcpy
#   .\download-assets.ps1 -Apk       只下 Termux 系列 APK
param([switch]$Scrcpy, [switch]$Apk, [switch]$Force)
$ErrorActionPreference = "Continue"
$root = Split-Path $PSScriptRoot -Parent
$all = (-not $Scrcpy -and -not $Apk)
function Say($m) { Write-Host "[*] $m" }

# ---------- scrcpy ----------
if ($all -or $Scrcpy) {
    $dst = Join-Path $root "scrcpy-win64-v5.0.1"
    if ((Test-Path $dst) -and -not $Force) {
        Say "scrcpy 已存在：$dst（加 -Force 重下）"
    } else {
        Say "查询 scrcpy 最新版本…"
        try {
            $rel = Invoke-RestMethod "https://api.github.com/repos/Genymobile/scrcpy/releases/latest" -Headers @{ 'User-Agent' = 'phonehost' } -TimeoutSec 30
            $asset = $rel.assets | Where-Object { $_.name -like "scrcpy-win64-v*.zip" } | Select-Object -First 1
            if (-not $asset) { throw "没找到 win64 压缩包" }
            Say ("下载 " + $asset.name + " (" + [math]::Round($asset.size/1MB,1) + " MB)")
            $zip = Join-Path $env:TEMP $asset.name
            Invoke-WebRequest $asset.browser_download_url -OutFile $zip -TimeoutSec 600 -UseBasicParsing
            Say "解压…"
            Expand-Archive -LiteralPath $zip -DestinationPath $root -Force
            $extracted = Get-ChildItem $root -Directory | Where-Object { $_.Name -like "scrcpy-win64-*" } | Select-Object -First 1
            if ($extracted -and $extracted.FullName -ne $dst) { Rename-Item $extracted.FullName $dst -Force }
            Remove-Item $zip -Force -ErrorAction SilentlyContinue
            Say "scrcpy 就位：$dst"
        } catch {
            Say ("下载失败：" + $_.Exception.Message)
            Say "手动下载：https://github.com/Genymobile/scrcpy/releases  解压到项目根目录，改名 scrcpy-win64-v5.0.1"
        }
    }
}

# ---------- Termux APK ----------
if ($all -or $Apk) {
    $dst = Join-Path $root "pc-mode"
    if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Path $dst -Force | Out-Null }
    # F-Droid 的稳定下载地址（版本会变，脚本只负责下载，失败就手动下）
    $apks = @(
        @{ name = "termux.apk";        url = "https://f-droid.org/repo/com.termux_1022.apk" },
        @{ name = "termux-x11.apk";    url = "https://github.com/termux/termux-x11/releases/download/nightly/app-arm64-v8a-debug.apk" },
        @{ name = "termux-api.apk";    url = "https://f-droid.org/repo/com.termux.api_51.apk" },
        @{ name = "termux-boot.apk";   url = "https://f-droid.org/repo/com.termux.boot_7.apk" },
        @{ name = "termux-widget.apk"; url = "https://f-droid.org/repo/com.termux.widget_12.apk" }
    )
    foreach ($a in $apks) {
        $out = Join-Path $dst $a.name
        if ((Test-Path $out) -and -not $Force) { Say ($a.name + " 已存在"); continue }
        Say ("下载 " + $a.name)
        try {
            Invoke-WebRequest $a.url -OutFile $out -TimeoutSec 300 -UseBasicParsing
            Say ("  ✓ " + [math]::Round((Get-Item $out).Length/1MB,1) + " MB")
        } catch {
            Say ("  × 失败：" + $a.url)
            Say "    可以到 F-Droid 或 GitHub Releases 手动下载，文件名改成上面这个名字放进 pc-mode\"
        }
    }
}

Say "完成。接下来看 docs\安装与使用.md"
