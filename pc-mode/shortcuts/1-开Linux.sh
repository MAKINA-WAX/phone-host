#!/data/data/com.termux/files/usr/bin/bash
# Termux:Widget 按钮：启动 Linux 桌面（后台跑起来 + 拿唤醒锁，防 MIUI 杀）
export HOME=/data/data/com.termux/files/home
export PREFIX=/data/data/com.termux/files/usr
export PATH=$PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$PREFIX/lib
export XDG_RUNTIME_DIR=$PREFIX/tmp
export TMPDIR=$PREFIX/tmp
mkdir -p $XDG_RUNTIME_DIR

# 唤醒锁：让 Termux 在前台服务里活着
termux-wake-lock 2>/dev/null || true

pkill -f 'termux-x11' 2>/dev/null
sleep 1
nohup termux-x11 :0 -ac > "$HOME/x11.log" 2>&1 &
sleep 3
DISPLAY=:0 XDG_SESSION_TYPE=x11 nohup startxfce4 > "$HOME/xfce.log" 2>&1 &
sleep 2

# 有虚拟屏就把它切到前台（PC 模式下的那块屏）
VD=$(dumpsys display 2>/dev/null | grep -o -E 'displayId [0-9]+' | awk '{print $2}' | grep -v '^0$' | sort -n | tail -1)
if [ -n "$VD" ]; then
  am start --display "$VD" --windowingMode 1 -n com.termux.x11/.MainActivity 2>/dev/null
fi
echo "Linux 已启动（display=${VD:-手机本机}）"
