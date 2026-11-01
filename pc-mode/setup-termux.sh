#!/data/data/com.termux/files/usr/bin/bash
# 用清华镜像装 X11 + XFCE（官方源在手机上很慢）
set -e
export DEBIAN_FRONTEND=noninteractive
export TERM=xterm-256color
P=/data/data/com.termux/files/usr

echo "=== [1/5] 换清华源 ==="
cp -f $P/etc/apt/sources.list $P/etc/apt/sources.list.bak 2>/dev/null || true
cat > $P/etc/apt/sources.list <<EOF
deb https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main stable main
EOF

echo "=== [2/5] apt update ==="
yes | apt update

echo "=== [3/5] x11-repo ==="
yes | apt install -y x11-repo || true
# x11-repo 会把官方源写进 sources.list.d，测一下它通不通
cat $P/etc/apt/sources.list.d/*.list 2>/dev/null || true
yes | apt update || true

echo "=== [4/5] 装 termux-x11 + xfce4 ==="
yes | apt install -y termux-x11-nightly xfce4 || yes | apt install -y termux-x11 xfce4

echo "=== [5/5] 标记完成 ==="
date > "$HOME/.xfce-ready"
echo "SETUP_OK"
