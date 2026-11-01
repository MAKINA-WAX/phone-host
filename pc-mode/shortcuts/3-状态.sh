#!/data/data/com.termux/files/usr/bin/bash
# Termux:Widget 按钮：看一眼当前状态
export HOME=/data/data/com.termux/files/home
export PREFIX=/data/data/com.termux/files/usr
export PATH=$PREFIX/bin:$PATH

echo "== 进程 =="
ps -A -o NAME 2>/dev/null | grep -E 'termux-x11|xfce4-session|xfwm4|xfce4-panel' | sort -u
echo "== 屏幕 =="
dumpsys display 2>/dev/null | grep -o -E 'displayId [0-9]+' | sort -u
echo "== 防杀后台 =="
dumpsys deviceidle whitelist 2>/dev/null | grep -i termux || echo "(未在白名单)"
echo "== 唤醒锁 =="
termux-wake-lock --status 2>/dev/null || echo "(无状态接口)"
