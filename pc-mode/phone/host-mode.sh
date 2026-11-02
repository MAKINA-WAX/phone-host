#!/data/data/com.termux/files/usr/bin/bash
# 模式仲裁 + 电量/温度调度（常驻守护）
#   插电   -> HOST 模式：起桌面（按 ~/.desktop-kind 选 LXQt 或 XFCE）+ 唤醒锁
#   拔电   -> PHONE 模式：停桌面 + 释放唤醒锁（省电）
#   温度 >= 60C -> 桌面进程降优先级
#   温度 >= 72C -> 停桌面保护手机并弹通知
#   温度 <  45C -> 恢复
export HOME=/data/data/com.termux/files/home
export PREFIX=/data/data/com.termux/files/usr
export PATH=$PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$PREFIX/lib
export XDG_RUNTIME_DIR=$PREFIX/tmp
export TMPDIR=$PREFIX/tmp

LOG=$HOME/host-mode.log
KIND_FILE=$HOME/.desktop-kind        # lxqt | xfce
INTERVAL=20
TEMP_HIGH=60
TEMP_STOP=72
TEMP_LOW=45
state=""

LOCK="$HOME/.host-mode.lock"
if [ -f "$LOCK" ]; then
  OLD=$(cat "$LOCK" 2>/dev/null)
  if [ -n "$OLD" ] && kill -0 "$OLD" 2>/dev/null; then
    echo "$(date '+%F %T') already running (pid $OLD), exit" >> "$LOG"
    exit 0
  fi
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

# 当前用哪个桌面（默认 lxqt）
desktop_kind() {
  if [ -f "$KIND_FILE" ]; then
    k=$(cat "$KIND_FILE" 2>/dev/null | tr -d '[:space:]')
    [ -n "$k" ] && { echo "$k"; return; }
  fi
  echo lxqt
}

desktop_on() {
  pgrep -f 'lxqt-panel|xfce4-session' >/dev/null 2>&1
}

start_host() {
  termux-wake-lock 2>/dev/null
  # 单实例保护：已经在跑就不重复起（避免出现两个桌面）
  if pgrep -f 'lxqt-panel|xfce4-session' >/dev/null 2>&1; then
    log "HOST mode: desktop already running, skip start"
    return
  fi
  # 起之前把另一套桌面残留清掉（start-lxqt.sh / start-xfce.sh 里也会清）
  local kind=$(desktop_kind)
  if [ "$kind" = "xfce" ]; then
    if ! pgrep -f 'termux-x11' >/dev/null 2>&1; then
      nohup termux-x11 :0 -ac -dpi 160 > "$HOME/x11.log" 2>&1 &
      sleep 4
    fi
    if ! pgrep -f xfce4-session >/dev/null 2>&1; then
      DISPLAY=:0 XDG_SESSION_TYPE=x11 nohup startxfce4 > "$HOME/xfce.log" 2>&1 &
    fi
    log "HOST mode: XFCE started, wake-lock on"
  else
    nohup bash "$HOME/start-lxqt.sh" > "$HOME/lxqt-boot.log" 2>&1 &
    log "HOST mode: LXQt started, wake-lock on"
  fi
}

stop_host() {
  killall -9 lxqt-panel lxqt-notificationd lxqt-powermanagement pcmanfm-qt openbox 2>/dev/null
  killall -9 xfce4-session xfwm4 xfdesktop xfce4-panel xfce4-power-manager xfce4-notifyd 2>/dev/null
  killall -9 termux-x11 2>/dev/null
  termux-wake-unlock 2>/dev/null
  log "PHONE mode: desktop stopped, wake-lock off"
}

throttle() {
  for p in $(pgrep -f 'lxqt-panel|openbox|pcmanfm-qt|xfce4-panel|termux-x11' 2>/dev/null); do
    renice "$1" -p "$p" >/dev/null 2>&1
  done
}

log "daemon start pid=$$ (interval ${INTERVAL}s, desktop=$(desktop_kind))"
while true; do
  bat=$(termux-battery-status 2>/dev/null)
  plugged=$(printf '%s' "$bat" | jq -r '.plugged // "?"' 2>/dev/null)
  temp=$(printf '%s' "$bat" | jq -r '.temperature // 0' 2>/dev/null)
  pct=$(printf '%s' "$bat" | jq -r '.percentage // 0' 2>/dev/null)
  ti=$(printf '%.0f' "${temp:-0}" 2>/dev/null || echo 0)

  if [ -n "$plugged" ] && [ "$plugged" != "PLUGGED_UNPLUGGED" ]; then
    if [ "$state" != "host" ] && [ "$state" != "throttled" ]; then
      state="host"; start_host
    fi
  else
    if [ "$state" != "phone" ]; then
      state="phone"; stop_host
    fi
  fi

  if [ "$state" = "host" ] || [ "$state" = "throttled" ]; then
    if [ "$ti" -ge "$TEMP_STOP" ]; then
      log "temp ${ti}C >= ${TEMP_STOP}C, stopping desktop"
      stop_host; state="cooling"
      termux-notification --title "手机过热" --content "${ti}C，已暂停 Linux 桌面" 2>/dev/null
    elif [ "$ti" -ge "$TEMP_HIGH" ] && [ "$state" = "host" ]; then
      throttle 19; state="throttled"
      log "temp ${ti}C, desktop renice 19"
    elif [ "$ti" -lt "$TEMP_LOW" ] && [ "$state" = "throttled" ]; then
      throttle 0; state="host"
      log "temp ${ti}C, priority restored"
    fi
  elif [ "$state" = "cooling" ] && [ "$ti" -lt "$TEMP_LOW" ]; then
    state="host"; start_host
    log "temp back to ${ti}C, host mode again"
  fi

  sleep "$INTERVAL"
done
