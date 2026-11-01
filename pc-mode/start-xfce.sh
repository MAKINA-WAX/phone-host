#!/data/data/com.termux/files/usr/bin/bash
# 启动 termux-x11 + XFCE 桌面
export HOME=/data/data/com.termux/files/home
export PREFIX=/data/data/com.termux/files/usr
export PATH=$PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$PREFIX/lib
export XDG_RUNTIME_DIR=$PREFIX/tmp
export TMPDIR=$PREFIX/tmp
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR 2>/dev/null

pkill -f 'termux-x11' 2>/dev/null
sleep 1

termux-x11 :0 -ac -dpi 144 > "$HOME/x11.log" 2>&1 &
sleep 3

export DISPLAY=:0
export XDG_SESSION_TYPE=x11

# XFCE 起来后把 X 资源里的 Xft.dpi 拉回一致（termux-x11 会按屏幕密度塞一个很大的值，导致面板字被裁）
( sleep 6; printf 'Xft.dpi: 160\n' | xrdb -merge 2>/dev/null; pkill -f xfce4-panel 2>/dev/null; sleep 1; nohup xfce4-panel >/dev/null 2>&1 & ) &

exec startxfce4 > "$HOME/xfce.log" 2>&1
