#!/data/data/com.termux/files/usr/bin/bash
# 手机端启动器（Termux TUI）
# 在手机上直接：看状态 / 开桌面 / 起守护 / 查权限 / 看启动清单
# 入口：Termux 里执行 ./launcher.sh，或桌面小组件 Termux:Widget -> 启动器
export HOME=/data/data/com.termux/files/home
export PREFIX=/data/data/com.termux/files/usr
export PATH=$PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$PREFIX/lib
export XDG_RUNTIME_DIR=$PREFIX/tmp
export TMPDIR=$PREFIX/tmp

C_B=$'\033[1m'; C_G=$'\033[32m'; C_Y=$'\033[33m'; C_R=$'\033[31m'; C_C=$'\033[36m'; C_0=$'\033[0m'

running() { pgrep -f "$1" >/dev/null 2>&1; }
ok()   { echo "${C_G}✓${C_0} $1"; }
bad()  { echo "${C_R}✗${C_0} $1"; }
warn() { echo "${C_Y}!${C_0} $1"; }

battery() {
  local j; j=$(termux-battery-status 2>/dev/null)
  if [ -n "$j" ]; then
    PCT=$(printf '%s' "$j" | jq -r '.percentage // "?"' 2>/dev/null)
    TEMP=$(printf '%s' "$j" | jq -r '.temperature // "?"' 2>/dev/null)
    PLUG=$(printf '%s' "$j" | jq -r '.plugged // "?"' 2>/dev/null | sed 's/PLUGGED_//')
  else
    PCT="?"; TEMP="?"; PLUG="?"
  fi
}

usbstate() {
  local u; u=$(getprop sys.usb.config 2>/dev/null)
  [ -z "$u" ] && u=$(getprop sys.usb.state 2>/dev/null)
  echo "$u"
}

header() {
  battery
  local usb xf hm nb
  usb=$(usbstate)
  running xfce4-session && xf="${C_G}运行中${C_0}" || xf="${C_R}已停${C_0}"
  running host-mode.sh   && hm="${C_G}运行中${C_0}" || hm="${C_R}已停${C_0}"
  running notify-bridge  && nb="${C_G}运行中${C_0}" || nb="${C_R}已停${C_0}"
  clear
  echo "${C_B}${C_C}=========================================="
  echo "           手机主机 · 启动器"
  echo "==========================================${C_0}"
  echo " 电量 ${C_B}${PCT}%${C_0}   温度 ${C_B}${TEMP}°C${C_0}   电源 ${C_B}${PLUG}${C_0}"
  echo " USB  ${C_B}${usb:-未知}${C_0}"
  echo " 桌面 ${xf}   主机守护 ${hm}   通知桥 ${nb}"
  echo "------------------------------------------"
}

menu() {
  echo "  ${C_B}1${C_0}) 开 Linux 桌面"
  echo "  ${C_B}2${C_0}) 关 Linux 桌面"
  echo "  ${C_B}3${C_0}) 启动主机守护（插电自动开桌面）"
  echo "  ${C_B}4${C_0}) 启动通知回传桥"
  echo "  ${C_B}5${C_0}) 环境自检（含权限）"
  echo "  ${C_B}6${C_0}) 权限设置入口（跳转系统页面）"
  echo "  ${C_B}7${C_0}) 查看日志"
  echo "  ${C_B}8${C_0}) 重启所有守护"
  echo "  ${C_B}9${C_0}) 启动清单 / 需要设置哪些东西"
  echo "  ${C_B}p${C_0}) 投屏到电脑（让电脑开虚拟屏）"
  echo "  ${C_B}q${C_0}) 手机镜像投到电脑"
  echo "  ${C_B}0${C_0}) 退出"
  echo "------------------------------------------"
}

start_desktop() {
  echo "启动 termux-x11 + XFCE …"
  if ! pgrep -f 'termux-x11' >/dev/null 2>&1; then
    nohup termux-x11 :0 -ac > "$HOME/x11.log" 2>&1 &
    sleep 4
  fi
  if ! running xfce4-session; then
    DISPLAY=:0 XDG_SESSION_TYPE=x11 nohup startxfce4 > "$HOME/xfce.log" 2>&1 &
    sleep 2
  fi
  termux-wake-lock 2>/dev/null
  ok "桌面已启动（在电脑上投屏看）"
  sleep 1
}

stop_desktop() {
  killall -9 xfce4-session xfwm4 xfdesktop xfce4-panel xfce4-power-manager xfce4-notifyd 2>/dev/null
  killall -9 termux-x11 2>/dev/null
  termux-wake-unlock 2>/dev/null
  ok "桌面已关闭"
  sleep 1
}

start_daemon() {
  if running "$1"; then warn "$2 已经在运行"; sleep 1; return; fi
  setsid nohup bash "$HOME/$1" > "$HOME/${1%.sh}.out" 2>&1 </dev/null &
  sleep 1
  running "$1" && ok "$2 已启动" || bad "$2 启动失败，看 ~/${1%.sh}.out"
  sleep 1
}

selfcheck() {
  clear
  echo "${C_B}环境自检${C_0}"
  echo
  if termux-battery-status >/dev/null 2>&1; then ok "termux-api 电池/温度 可用"; else bad "termux-api 不可用（Termux:API 没装或没授权）"; fi

  local nout; nout=$(timeout 8 termux-notification-list 2>/dev/null); local nrc=$?
  if [ $nrc -eq 0 ] && [ -n "$nout" ]; then ok "通知读取权限 已授予（当前有通知）"
  elif [ $nrc -eq 0 ]; then ok "通知读取权限 已授予（当前没通知）"
  else bad "通知读取权限 未授予 → 菜单 6 打开通知使用权"; fi

  if pm list packages com.termux.x11 2>/dev/null | grep -q "com.termux.x11"; then ok "Termux:X11 已安装"; else warn "Termux:X11 包名查不到（可能只是查询受限）"; fi
  command -v startxfce4 >/dev/null 2>&1 && ok "XFCE 已安装" || bad "XFCE 未安装"
  command -v termux-x11 >/dev/null 2>&1 && ok "termux-x11 命令可用" || bad "termux-x11 命令缺失"

  running host-mode.sh  && ok "主机守护 运行中" || warn "主机守护 未运行"
  running notify-bridge && ok "通知桥 运行中" || warn "通知桥 未运行"
  termux-wake-lock 2>/dev/null && ok "唤醒锁 可用" || bad "唤醒锁 不可用"

  local usb; usb=$(usbstate)
  case "$usb" in
    *adb*) ok "USB 已连电脑（adb 通道正常，电脑端可投屏）" ;;
    *)     warn "USB 未连电脑（当前: ${usb:-未知}）——投屏需要数据线" ;;
  esac

  [ -f "$HOME/start-xfce.sh" ] && ok "start-xfce.sh 存在" || bad "start-xfce.sh 缺失"
  [ -f "$HOME/host-mode.sh" ]  && ok "host-mode.sh 存在"  || bad "host-mode.sh 缺失"
  echo
  echo "${C_Y}以下三项只能在 MIUI 设置里手动开（adb 开不了）：${C_0}"
  echo "  · 省电策略 = 无限制（Termux、Termux:X11）"
  echo "  · 自启动 = 允许（Termux、Termux:X11）"
  echo "  · 最近任务里下拉锁定 Termux"
  echo
  read -r -p "回车返回" _
}

perm_menu() {
  while true; do
    header
    echo "  ${C_B}1${C_0}) 通知使用权（Termux:API）"
    echo "  ${C_B}2${C_0}) Termux 应用详情（省电/自启动）"
    echo "  ${C_B}3${C_0}) Termux:X11 应用详情"
    echo "  ${C_B}4${C_0}) 开发者选项"
    echo "  ${C_B}0${C_0}) 返回"
    echo "------------------------------------------"
    read -r -n 1 -p "选择: " c
    case "$c" in
      1) am start -a android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS >/dev/null 2>&1 ; sleep 1 ;;
      2) am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d package:com.termux >/dev/null 2>&1 ; sleep 1 ;;
      3) am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d package:com.termux.x11 >/dev/null 2>&1 ; sleep 1 ;;
      4) am start -a android.settings.APPLICATION_DEVELOPMENT_SETTINGS >/dev/null 2>&1 ; sleep 1 ;;
      0) return ;;
    esac
  done
}

show_logs() {
  clear
  echo "${C_B}主机守护日志${C_0}"
  tail -n 12 "$HOME/host-mode.log" 2>/dev/null || echo "(无)"
  echo
  echo "${C_B}通知桥日志${C_0}"
  tail -n 8 "$HOME/notify-bridge.log" 2>/dev/null || echo "(无)"
  echo
  read -r -p "回车返回" _
}

request_display() {
  local mode="$1"
  echo "$mode" > "$HOME/.pc-display-request"
  termux-notification --title "已请求投屏" --content "电脑端 5 秒内响应（$mode）" 2>/dev/null
  ok "已发送请求：$mode"
  echo "   电脑端守护会在 5 秒内建好虚拟屏并投出来"
  echo "   如果 30 秒没反应，检查电脑上 watch-reconnect 是否在跑"
  sleep 2
}

checklist() {
  clear
  echo "${C_B}启动清单${C_0}"
  echo
  echo "${C_B}一、手机上必须装的 App${C_0}"
  echo "  Termux          —— 跑 Linux 和脚本"
  echo "  Termux:X11      —— 把 Linux 桌面显示出来"
  echo "  Termux:API      —— 读电量/温度/通知（手机端功能依赖它）"
  echo "  Termux:Boot     —— 开机自动拉起守护"
  echo "  Termux:Widget   —— 桌面小组件，一键打开本启动器"
  echo
  echo "${C_B}二、手机上必须开的系统开关${C_0}"
  echo "  开发者选项 → USB 调试（安全设置）  <- 电脑投屏/注入触摸必需"
  echo "  通知使用权 → Termux:API（菜单 6 可直接跳转）"
  echo "  省电策略 = 无限制（Termux、Termux:X11）"
  echo "  自启动 = 允许（Termux、Termux:X11）"
  echo "  最近任务里下拉锁定 Termux（防清理）"
  echo
  echo "${C_B}三、使用顺序${C_0}"
  echo "  1) 手机插线连电脑（USB 调试已授权）"
  echo "  2) 电脑上跑 mirror-game-vd.bat / mirror-window.bat / mirror-touch.bat"
  echo "  3) 想用 Linux 桌面：本菜单 1) 开 Linux 桌面"
  echo "  4) 收工：电脑端 stop-pc.bat"
  echo
  read -r -p "回车返回" _
}

while true; do
  header
  menu
  read -r -n 1 -p "选择: " choice
  echo
  case "$choice" in
    1) start_desktop ;;
    2) stop_desktop ;;
    3) start_daemon host-mode.sh 主机守护 ;;
    4) start_daemon notify-bridge.sh 通知桥 ;;
    5) selfcheck ;;
    6) perm_menu ;;
    7) show_logs ;;
    8)
      pkill -f host-mode.sh 2>/dev/null; pkill -f notify-bridge.sh 2>/dev/null
      sleep 1
      start_daemon host-mode.sh 主机守护
      start_daemon notify-bridge.sh 通知桥
      ;;
    9) checklist ;;
    p) request_display canvas ;;
    q) request_display mirror ;;
    0) clear; echo "已退出。"; exit 0 ;;
    *) ;;
  esac
done
