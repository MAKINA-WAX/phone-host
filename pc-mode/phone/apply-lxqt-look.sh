#!/data/data/com.termux/files/usr/bin/bash
# 一键应用 LXQt 的"好看"配置（图标主题 / Qt 风格 / 字体 / 面板浅色主题与尺寸 / 壁纸）
export HOME=/data/data/com.termux/files/home
export PREFIX=/data/data/com.termux/files/usr
export PATH=$PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$PREFIX/lib
export DISPLAY=:0
export XDG_RUNTIME_DIR=$PREFIX/tmp

mkdir -p "$HOME/.config/lxqt" "$HOME/.config/pcmanfm-qt/default"

# 1) 外观：Adwaita 图标 + Fusion 风格 + Noto Sans 11 + light 主题
printf '%s\n' \
'[General]' \
'__userfile__=true' \
'icon_theme=Adwaita' \
'style=Fusion' \
'font=Noto Sans,13' \
'theme=light' > "$HOME/.config/lxqt/lxqt.conf"

# 2) 面板：浅色主题 + 44 高 + 图标 32 + 满宽底部 + 背景半透明
if grep -q '^\[panel1\]' "$HOME/.config/lxqt/panel.conf"; then
  sed -i 's/^panelSize=.*/panelSize=52/; s/^iconSize=.*/iconSize=40/' "$HOME/.config/lxqt/panel.conf"
else
  printf '\n[panel1]\nalignment=-1\niconSize=40\nlineCount=1\nlockPanel=false\npanelSize=52\nposition=Bottom\nlength=100\nlength-percent=true\n' >> "$HOME/.config/lxqt/panel.conf"
fi
grep -q '^theme=' "$HOME/.config/lxqt/panel.conf" || printf '\ntheme=light\n' >> "$HOME/.config/lxqt/panel.conf"

# 3) 壁纸
printf '[Desktop]\nWallpaper=%s\nWallpaperMode=zoom\nBgColor=#1e2a38\nFgColor=#ffffff\nShadowColor=#000000\n' \
  "$PREFIX/share/lxqt/wallpapers/Valendas.png" > "$HOME/.config/pcmanfm-qt/default/settings.conf"

# 4) 重启面板与桌面
export DBUS_SESSION_BUS_ADDRESS=$(dbus-daemon --session --fork --print-address 2>/dev/null)
pkill -9 -f lxqt-panel 2>/dev/null
sleep 1
nohup lxqt-panel > "$HOME/lxqt-panel.log" 2>&1 &
sleep 2
pkill -f pcmanfm-qt 2>/dev/null
sleep 1
nohup pcmanfm-qt --desktop > "$HOME/pcmanfm.log" 2>&1 &
sleep 2
echo "LXQt 外观已应用（light 主题 / Adwaita 图标 / Fusion / 44px 面板）"
