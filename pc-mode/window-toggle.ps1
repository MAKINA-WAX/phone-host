# 在「全屏」和「窗口」之间切换投屏窗口（可用快捷键 Ctrl+Alt+F）
# 全屏 = 无边框铺满屏幕；窗口 = 1280x720 居中（仍是无边框，但可以用鼠标拖标题区移动？无边框不能拖，所以窗口状态会加回边框）
$ErrorActionPreference = "Continue"
$localTemp = Join-Path $PSScriptRoot "tmp"
if (-not (Test-Path $localTemp)) { New-Item -ItemType Directory -Path $localTemp -Force | Out-Null }
$env:TEMP = $localTemp
$env:TMP = $localTemp

Add-Type -Name Win -Namespace Tgl -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
[DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
[DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int i, int v);
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
'@
[void][Tgl.Win]::SetProcessDpiAwarenessContext([IntPtr](-4))

$p = Get-Process scrcpy -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) { Write-Host "没有正在运行的投屏窗口"; exit 1 }
$h = $p.MainWindowHandle

$r = New-Object Tgl.Win+RECT
[void][Tgl.Win]::GetWindowRect($h, [ref]$r)
$curW = $r.Right - $r.Left
$curH = $r.Bottom - $r.Top
$sw = [Tgl.Win]::GetSystemMetrics(0)
$sh = [Tgl.Win]::GetSystemMetrics(1)

$SWP_NOZORDER = 0x0004
$SWP_SHOWWINDOW = 0x0040
$flags = $SWP_NOZORDER -bor $SWP_SHOWWINDOW
$GWL_STYLE = -16
$WS_CAPTION = 0x00C00000
$WS_THICKFRAME = 0x00040000

$isFull = ($curW -ge $sw - 8 -and $curH -ge $sh - 8)
if ($isFull) {
    # → 窗口：加回标题栏+边框，尺寸 1280x720 居中
    $style = [Tgl.Win]::GetWindowLong($h, $GWL_STYLE)
    [void][Tgl.Win]::SetWindowLong($h, $GWL_STYLE, ($style -bor $WS_CAPTION -bor $WS_THICKFRAME))
    $w = [int]($sw * 0.46); $ht = [int]($w * 9 / 16)
    if ($ht -gt ($sh * 0.85)) { $ht = [int]($sh * 0.85); $w = [int]($ht * 16 / 9) }
    [void][Tgl.Win]::SetWindowPos($h, [IntPtr]::Zero, [int](($sw - $w) / 2), [int](($sh - $ht) / 2), $w, $ht, $flags)
    Write-Host "已切到窗口模式 ${w}x${ht}（可以用鼠标拖标题栏）"
} else {
    # → 全屏：去掉标题栏，铺满
    $style = [Tgl.Win]::GetWindowLong($h, $GWL_STYLE)
    [void][Tgl.Win]::SetWindowLong($h, $GWL_STYLE, ($style -band (-bnot ($WS_CAPTION -bor $WS_THICKFRAME))))
    [void][Tgl.Win]::SetWindowPos($h, [IntPtr]::Zero, 0, 0, $sw, $sh, $flags)
    Write-Host "已切到全屏 $($sw)x$($sh)"
}
[void][Tgl.Win]::SetForegroundWindow($h)
