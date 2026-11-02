#!/data/data/com.termux/files/usr/bin/bash
# 应用界面缩放：apply-scale.sh <缩放倍数> [DPI] [面板高] [图标] [字号]
#   apply-scale.sh 1.25          → 自动算 DPI/面板/图标/字号
#   apply-scale.sh 1.5 240 66 48 15
export HOME=/data/data/com.termux/files/home
export PREFIX=/data/data/com.termux/files/usr
export PATH=$PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$PREFIX/lib
export DISPLAY=:0
export XDG_RUNTIME_DIR=$PREFIX/tmp

SCALE=${1:-1.25}
DPI=${2:-$(awk "BEGIN{printf \"%d\", 160*$SCALE}")}
PANEL=${3:-$(awk "BEGIN{printf \"%d\", 44*$SCALE}")}
ICON=${4:-$(awk "BEGIN{printf \"%d\", 32*$SCALE}")}
FONT=${5:-$(awk "BEGIN{s=$SCALE; if(s>=1.45) print 15; else if(s>=1.15) print 13; else print 11}")}

echo "缩放 $SCALE 倍 → DPI $DPI / 面板 ${PANEL}px / 图标 ${ICON}px / 字体 ${FONT}"

# 1) 启动脚本里的 UI_SCALE（下次开桌面生效）
sed -i "s/^UI_SCALE=.*/UI_SCALE=$SCALE/" "$HOME/start-lxqt.sh" 2>/dev/null
grep '^UI_SCALE=' "$HOME/start-lxqt.sh" 2>/dev/null

# 2) 面板尺寸
sed -i "s/^panelSize=.*/panelSize=$PANEL/; s/^iconSize=.*/iconSize=$ICON/" "$HOME/.config/lxqt/panel.conf" 2>/dev/null

# 3) 桌面字体
sed -i "s/^font=Noto Sans,.*/font=Noto Sans,$FONT/" "$HOME/.config/lxqt/lxqt.conf" 2>/dev/null

# 4) Firefox 缩放
for f in "$HOME"/.config/mozilla/firefox/*/user.js; do
  [ -f "$f" ] || continue
  printf 'user_pref("layout.css.devPixelsPerPx", "%s");\n' "$SCALE" > "$f"
  echo "Firefox: $f"
done

# 5) GTK 应用用的 Xft.dpi
printf 'Xft.dpi: %s\nXft.antialias: 1\nXft.hinting: 1\nXft.rgba: rgb\n' "$DPI" > "$HOME/.Xresources"
xrdb -merge "$HOME/.Xresources" 2>/dev/null
echo "Xft.dpi = $(xrdb -query 2>/dev/null | grep -i xft.dpi | awk '{print $2}')"

# 6) 已有面板进程重新读取配置
if pgrep -f lxqt-panel >/dev/null 2>&1; then
  echo "面板尺寸改动需要重启桌面才完全生效（可用 桌面缩放.bat 或重启 LXQt）"
fi
echo "done"
