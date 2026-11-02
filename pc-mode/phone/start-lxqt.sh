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

# 停旧会话（XFCE / LXQt 全杀，保证只有一个桌面）
for p in lxqt-panel lxqt-notificationd lxqt-powermanagement pcmanfm-qt openbox \
         xfce4-panel xfdesktop xfwm4 xfce4-session xfce4-power-manager xfce4-notifyd; do
  pkill -9 -f "$p" 2>/dev/null
done
sleep 2

# X 服务器也重起，避免旧连接残留
pkill -9 -f 'termux-x11' 2>/dev/null
sleep 1
termux-x11 :0 -ac -dpi 160 > "$HOME/x11.log" 2>&1 &
sleep 3

export DISPLAY=:0
export XDG_SESSION_TYPE=x11

# ---- 界面缩放（改这一个数就行）----
# 1.00 = 原始；1.25 = 放大 25%；1.5 = 放大 50%
UI_SCALE=1.25
BASE_DPI=160
UI_DPI=$(awk "BEGIN{printf \"%d\", $BASE_DPI * $UI_SCALE}")

export QT_SCALE_FACTOR=$UI_SCALE
export QT_FONT_DPI=$UI_DPI
export QT_AUTO_SCREEN_SCALE_FACTOR=0

# ---- 中文输入法（fcitx5）----
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
export SDL_IM_MODULE=ibus
export XIM=ibus
export XIM_PROGRAM=ibus
export IBUS_ENABLE_SYNC_MODE=1

# ---- 声音输出（PulseAudio → Android OpenSL ES）----
export PULSE_SERVER="unix:$PREFIX/tmp/pulse/native"
export PULSE_RUNTIME_PATH="$PREFIX/tmp/pulse"
if ! pgrep -f "pulseaudio --start" >/dev/null 2>&1; then
  pulseaudio --start --exit-idle-time=-1 > "$HOME/pulse.log" 2>&1
  sleep 2
fi
export GDK_SCALE=1
export GDK_DPI_SCALE=$UI_SCALE

# 独立 D-Bus 会话（面板/托盘必须有）
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ] || [ ! -S "${DBUS_SESSION_BUS_ADDRESS#unix:path=}" ] 2>/dev/null; then
  ADDR=$(dbus-daemon --session --fork --print-address 2>/dev/null)
  [ -n "$ADDR" ] && export DBUS_SESSION_BUS_ADDRESS="$ADDR"
fi
printf 'Xft.dpi: %s\nXft.antialias: 1\nXft.hinting: 1\nXft.rgba: rgb\n' "$UI_DPI" | xrdb -merge 2>/dev/null

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
nohup ibus-daemon -drx > "$HOME/ibus.log" 2>&1 &
sleep 3
ibus engine libpinyin >/dev/null 2>&1
sleep 2
nohup lxqt-panel > "$HOME/lxqt-panel.log" 2>&1 &
sleep 3

bash "$HOME/apply-lxqt-look.sh" >/dev/null 2>&1 &
echo "LXQt 启动完成（dbus: ${DBUS_SESSION_BUS_ADDRESS:0:20}...）"
