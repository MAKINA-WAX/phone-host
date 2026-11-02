#!/data/data/com.termux/files/usr/bin/bash
# Start termux-x11 + XFCE.  SINGLE INSTANCE: kills any existing desktop first
# (both XFCE and LXQt), so you never end up with two desktops running.
export HOME=/data/data/com.termux/files/home
export PREFIX=/data/data/com.termux/files/usr
export PATH=$PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$PREFIX/lib
export XDG_RUNTIME_DIR=$PREFIX/tmp
export TMPDIR=$PREFIX/tmp
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR 2>/dev/null

# --- 1) kill EVERY desktop process (xfce + lxqt) and the old X server ---
for p in xfce4-session xfwm4 xfdesktop xfce4-panel xfce4-power-manager xfce4-notifyd \
         lxqt-panel lxqt-notificationd lxqt-powermanagement pcmanfm-qt openbox \
         termux-x11; do
  pkill -9 -f "$p" 2>/dev/null
done
sleep 2

# --- 2) start one X server ---
termux-x11 :0 -ac -dpi 160 > "$HOME/x11.log" 2>&1 &
sleep 3

export DISPLAY=:0
export XDG_SESSION_TYPE=x11

# --- 3) set DPI BEFORE the session starts (no panel respawn hack needed) ---
printf 'Xft.dpi: 160\n' | xrdb -merge 2>/dev/null

# --- 4) start ONE xfce session ---
exec startxfce4 > "$HOME/xfce.log" 2>&1
