# 手柄自检：实时显示 Windows 看到的 XInput 手柄状态
# 用法: 双击 test-pad.bat，然后按手柄按键，看按钮有没有亮起来
Add-Type -Namespace Xt -Name Pad -MemberDefinition @'
[DllImport("xinput1_4.dll")] public static extern int XInputGetState(int idx, ref XINPUT_STATE s);
[StructLayout(LayoutKind.Sequential)] public struct XINPUT_GAMEPAD { public ushort wButtons; public byte bLeftTrigger, bRightTrigger; public short sThumbLX, sThumbLY, sThumbRX, sThumbRY; }
[StructLayout(LayoutKind.Sequential)] public struct XINPUT_STATE { public uint dwPacketNumber; public XINPUT_GAMEPAD Gamepad; }
'@

function Button-Names([int]$b) {
    $map = @{
        0x0001='D-Pad 上'; 0x0002='D-Pad 下'; 0x0004='D-Pad 左'; 0x0008='D-Pad 右'
        0x0010='Start'; 0x0020='Back'; 0x0040='左摇杆按下'; 0x0080='右摇杆按下'
        0x0100='LB'; 0x0200='RB'; 0x1000='A'; 0x2000='B'; 0x4000='X'; 0x8000='Y'
    }
    $names = @()
    foreach ($k in $map.Keys) { if ($b -band $k) { $names += $map[$k] } }
    return ($names -join ',')
}

Write-Host "按手柄任意键，观察 A/B/X/Y 和摇杆是否变化。30 秒后自动结束。" -ForegroundColor Cyan
$start = Get-Date
while (((Get-Date) - $start).TotalSeconds -lt 30) {
    $s = New-Object Xt.Pad+XINPUT_STATE
    $r = [Xt.Pad]::XInputGetState(0, [ref]$s)
    if ($r -eq 0) {
        $btns = Button-Names $s.Gamepad.wButtons
        if (-not $btns) { $btns = '-' }
        $line = "btn=0x{0:X4} [{1}]  LX={2,6} LY={3,6} RX={4,6} RY={5,6}  LT={6,3} RT={7,3}" -f `
            $s.Gamepad.wButtons, $btns, $s.Gamepad.sThumbLX, $s.Gamepad.sThumbLY, `
            $s.Gamepad.sThumbRX, $s.Gamepad.sThumbRY, $s.Gamepad.bLeftTrigger, $s.Gamepad.bRightTrigger
        Write-Host $line
    } else {
        Write-Host "XInput 没有检测到手柄（返回码 $r，1167 = 未连接）" -ForegroundColor Yellow
    }
    Start-Sleep -Milliseconds 200
}
Write-Host "结束。" -ForegroundColor Cyan
