# 把 scrcpy 窗口拉到前台（bat 里 start 出来的窗口有时会躲在浏览器后面）
Add-Type -Name W -Namespace ScrcpyFocus -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
'@

for ($i = 0; $i -lt 60; $i++) {
    $p = Get-Process scrcpy -ErrorAction SilentlyContinue |
         Where-Object { $_.MainWindowHandle -ne 0 } |
         Select-Object -First 1
    if ($p) {
        [ScrcpyFocus.W]::ShowWindow($p.MainWindowHandle, 9) | Out-Null    # SW_RESTORE
        [ScrcpyFocus.W]::BringWindowToTop($p.MainWindowHandle) | Out-Null
        [ScrcpyFocus.W]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
        break
    }
    Start-Sleep -Milliseconds 250
}
