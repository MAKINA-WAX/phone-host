#!/data/data/com.termux/files/usr/bin/bash
# Termux:Widget 按钮：停止 Linux 桌面，并释放唤醒锁
export HOME=/data/data/com.termux/files/home
export PREFIX=/data/data/com.termux/files/usr
export PATH=$PREFIX/bin:$PATH

killall -9 xfce4-session xfwm4 xfdesktop xfce4-panel xfce4-power-manager xfce4-notifyd 2>/dev/null
killall -9 termux-x11 2>/dev/null
termux-wake-unlock 2>/dev/null || true
echo "Linux 已停止"
