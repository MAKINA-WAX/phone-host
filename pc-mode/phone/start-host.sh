#!/data/data/com.termux/files/usr/bin/bash
# 开机自启（由 Termux:Boot 调用）：拉起模式仲裁守护 + sshd
export HOME=/data/data/com.termux/files/home
export PREFIX=/data/data/com.termux/files/usr
export PATH=$PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$PREFIX/lib
export XDG_RUNTIME_DIR=$PREFIX/tmp

echo "$(date '+%F %T') boot script" >> "$HOME/boot.log"

# 1) 模式仲裁守护
if ! pgrep -f host-mode.sh >/dev/null 2>&1; then
  nohup bash "$HOME/host-mode.sh" > "$HOME/host-mode.out" 2>&1 &
  echo "$(date '+%F %T') host-mode started" >> "$HOME/boot.log"
fi

# 2) 通知回传守护
if ! pgrep -f notify-bridge.sh >/dev/null 2>&1; then
  nohup bash "$HOME/notify-bridge.sh" > "$HOME/notify-bridge.out" 2>&1 &
  echo "$(date '+%F %T') notify-bridge started" >> "$HOME/boot.log"
fi

# 3) SSH（若已配置 host key）
if [ -x "$PREFIX/bin/sshd" ] && [ -f "$HOME/.ssh/id_ed25519" ]; then
  pgrep -x sshd >/dev/null 2>&1 || sshd
  echo "$(date '+%F %T') sshd started" >> "$HOME/boot.log"
fi
