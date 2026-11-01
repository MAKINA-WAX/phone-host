#!/data/data/com.termux/files/usr/bin/bash
# 启动 termux-x11 + LXQt（openbox + 面板 + 桌面），带独立 D-Bus 会话
export HOME=/data/data/com.termux/files/home
export PREFIX=/data/data/com.termux/files/usr
export PATH=$PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$PREFIX/lib
export XDG_RUNTIME_DIR=$PREFIX/tmp
export TMPDIR=$PREFIX/tmp
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR 2>/dev/null

# 停旧会话（XFCE / LXQt）
for p in lxqt-panel lxqt-notificationd lxqt-powermanagement pcmanfm-qt openbox \
         xfce4-panel xfdesktop xfwm4 xfce4-session xfce4-notifyd; do
  pkill -f "$p" 2>/dev/null
done
sleep 1

if ! pgrep -f 'termux-x11' >/dev/null 2>&1; then
  termux-x11 :0 -ac -dpi 160 > "$HOME/x11.log" 2>&1 &
  sleep 3
fi

export DISPLAY=:0
export XDG_SESSION_TYPE=x11
export QT_SCALE_FACTOR=1
export QT_FONT_DPI=160
export QT_AUTO_SCREEN_SCALE_FACTOR=0

# 独立 D-Bus 会话（面板/托盘必须有）
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ] || [ ! -S "${DBUS_SESSION_BUS_ADDRESS#unix:path=}" ] 2>/dev/null; then
  ADDR=$(dbus-daemon --session --fork --print-address 2>/dev/null)
  [ -n "$ADDR" ] && export DBUS_SESSION_BUS_ADDRESS="$ADDR"
fi
printf 'Xft.dpi: 160\n' | xrdb -merge 2>/dev/null

# 桌面壁纸配置
mkdir -p "$HOME/.config/pcmanfm-qt/default"
printf '[Desktop]\nWallpaper=%s\nWallpaperMode=zoom\nBgColor=#1e2a38\nFgColor=#ffffff\nShadowColor=#000000\nDesktopShortcuts=HOME,TRASH\n' \
  "$PREFIX/share/lxqt/wallpapers/Valendas.png" > "$HOME/.config/pcmanfm-qt/default/settings.conf"

nohup openbox > "$HOME/openbox.log" 2>&1 &
sleep 2
nohup lxqt-notificationd > "$HOME/lxqt-notify.log" 2>&1 &
nohup lxqt-powermanagement > "$HOME/lxqt-pm.log" 2>&1 &
sleep 1
nohup pcmanfm-qt --desktop > "$HOME/pcmanfm.log" 2>&1 &
sleep 2
nohup lxqt-panel > "$HOME/lxqt-panel.log" 2>&1 &
sleep 3

bash "$HOME/apply-lxqt-look.sh" >/dev/null 2>&1 &
echo "LXQt 启动完成（dbus: ${DBUS_SESSION_BUS_ADDRESS:0:20}...）"
