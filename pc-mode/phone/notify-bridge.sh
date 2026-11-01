#!/data/data/com.termux/files/usr/bin/bash
# Forward Android notifications to the XFCE desktop (only while XFCE runs).
export HOME=/data/data/com.termux/files/home
export PREFIX=/data/data/com.termux/files/usr
export PATH=$PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$PREFIX/lib

# single instance lock
LOCK="$HOME/.notify-bridge.lock"
if [ -f "$LOCK" ]; then
  OLD=$(cat "$LOCK" 2>/dev/null)
  if [ -n "$OLD" ] && kill -0 "$OLD" 2>/dev/null; then exit 0; fi
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

SEEN=$HOME/.notif-seen
touch "$SEEN"
echo "$(date '+%F %T') notify-bridge start pid=$$" >> "$HOME/notify-bridge.log"

has_desktop() { pgrep -f xfce4-session >/dev/null 2>&1; }
can_notify()  { command -v notify-send >/dev/null 2>&1; }

while true; do
  if has_desktop && can_notify; then
    timeout 15 termux-notification-list 2>/dev/null \
      | jq -r '.[] | select((.content // "") != "") | "\(.title // "notify")|\(.content)"' 2>/dev/null \
      | sort -u \
      | while IFS='|' read -r t c; do
          [ -z "$c" ] && continue
          h=$(printf '%s|%s' "$t" "$c" | md5sum | cut -d' ' -f1)
          if ! grep -qx "$h" "$SEEN" 2>/dev/null; then
            DISPLAY=:0 notify-send -a "Android" -t 8000 "$t" "$c" >/dev/null 2>&1
            echo "$h" >> "$SEEN"
          fi
        done
    tail -800 "$SEEN" > "$SEEN.tmp" 2>/dev/null && mv "$SEEN.tmp" "$SEEN" 2>/dev/null
  fi
  sleep 25
done
