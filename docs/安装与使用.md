# 手机当主机 · “PC 模式”（DeX 风格）落地方案

> **现状：已经跑起来了，而且是真·多窗口。**
> 一条 `2-start-pc.bat`，PC 显示器上就是一块 1600×1000 的桌面：底部 Taskbar（开始菜单 + 应用图标 + 托盘时钟），上面是好几个可以拖动缩放的窗口。
> 而且——**不需要那个「USB 调试（安全设置）」开关**。虚拟屏上的应用默认就是 freeform 窗口。

![demo](demo-chrome.png)

---

## 1. 关键发现（省掉了所有系统权限）

| 探测项 | 结果 |
|---|---|
| `scrcpy --new-display=1600x1000/220` | ✅ 手机上真的多一块独立屏，本机屏幕照常刷微信打电话 |
| 虚拟屏上的应用窗口模式 | ✅ **`mode=freeform`**，Chrome / 设置 / 计算器同时开，各自一个窗口 |
| Taskbar 在虚拟屏上 | ✅ 自动变成底部任务栏：开始菜单、应用图标、蓝牙/WiFi/电量/时钟托盘 |
| 空虚拟屏 | ⚠️ 不启动任何 App 会被回收 → 脚本一律带 `--start-app` |
| `settings put enable_freeform_support` | ❌ 仍然被拒（`WRITE_SECURE_SETTINGS`），**但现在不需要了** |
| `input tap/swipe` 自动化 | ❌ `INJECT_EVENTS` 被拒，同一类开关管的 |
| Type-C 直连显示器 | ❌ 无 DP 输出（K70 系列 USB 2.0） |

**为什么之前说“需要开关”？** 因为 `enable_freeform_support` 管的是**手机本机屏幕**能不能开小窗。而这套方案根本不碰本机屏幕——所有窗口都长在那块 1600×1000 的虚拟屏上，系统对虚拟屏默认就是 freeform。

---

## 2. 怎么玩

```bat
cd pc-mode
2-start-pc.bat
```

窗口里能做的事（键鼠是直通的，等于把手机当主机）：

| 操作 | 说明 |
|---|---|
| 鼠标拖动窗口顶部把手 | 移动窗口；拖边缘可改大小（移动应用的 freeform 支持程度不同） |
| 点底部任务栏图标 | 切换 / 秒开常用 App，左端是开始菜单 |
| 键盘直接打字 | 浏览器地址栏、微信、文档都能直接输入中文 |
| `Alt+Q` | 退出投屏（回到你的 Windows） |
| `Alt+F` | 全屏 / 窗口切换 |
| `Alt+g` | 1:1 像素显示 |
| `Alt+O` | 开关手机本机屏幕 |

想让它一开机就是某个 App：改 `2-start-pc.bat` 里的 `set "APP=..."`（包名），或另开：
```bat
scrcpy -d --new-display=1600x1000/220 --start-app=?bilibili ...
```

已经在虚拟屏上时，想再开一个窗口：
```bat
adb -d shell "am start --display <虚拟屏id> -n com.miui.calculator/.cal.CalculatorActivity"
```
（`<虚拟屏id>` = `adb shell dumpsys display | findstr displayId`，每次启动都会变）

---

## 3. 那个开发者开关还要不要开？

**不用了。** 开着的好处只有两个，都属于“锦上添花”：

- 手机本机屏幕也能开小窗（不用虚拟屏时）
- `wm size` / `wm density` 这类改系统参数的命令能用

如果你想在**手机本机**上也能窗口化（比如出门只带手机），再手动开：
设置 → 更多设置 → 开发者选项 → 「USB 调试（安全设置）」，然后 `1-enable-freeform.bat` + 重启。

---

## 4. Taskbar 里值得调的项（可选）

- **常规设置** → 顶部总开关；“Taskbar 作为主屏幕”
- **外观** → 任务栏大小 / 位置 / 图标数量（默认图标偏大，可以调小）
- **桌面模式** → 桌面图标、右键菜单、更像 PC 的交互
- **最近应用** → 可视版 Alt+Tab
- **自由式模式** → 这里的开关依赖系统 freeform 设置，虚拟屏上不开也能用窗口，别纠结

---

## 5. 已知坑（脚本里都已绕过）

| 坑 | 现象 | 处理 |
|---|---|---|
| 空虚拟屏被回收 | 只给 `--new-display` 时屏一会儿就没了 | 脚本一律带 `--start-app` |
| adb 写日志被拒 | `cannot open ...\Temp\adb.log: Permission denied`（这台 PC 的 %TEMP% 有怪问题） | bat 内把 `TEMP/TMP` 指到 `pc-mode\tmp\` |
| 窗口躲到浏览器后面 | 以为没启动 | `focus-scrcpy.ps1` 自动前置 |
| bat 中文乱码 / 命令被吞 | cmd 对 LF+UTF-8 批处理会错位 | 批处理统一 CRLF + ASCII |

---

## 6. 还能更进一步

1. **窗口大小记忆**：现在每次启动窗口都是手机默认尺寸，可以接受；想要更整齐，等 freeform 系统开关开了再用 `am task resize`
2. **多屏**：`--new-display` 可以起多块屏（受系统虚拟屏数量限制），PC 侧开多窗口分别看
3. **真 Linux 桌面**：Termux + `termux-x11` + XFCE，任意窗口、菜单栏、文件管理器全套
   ```bash
   pkg install x11-repo termux-x11-nightly xfce4
   termux-x11 :0 & startxfce4
   ```

---

## 7. 文件清单

| 文件 | 作用 |
|---|---|
| `2-start-pc.bat` | **一键进 PC 模式**（虚拟屏 + 满屏 + 自动前置），已验证 |
| `1-enable-freeform.bat` | 可选：给手机本机开 freeform（需要开发者开关 + 重启） |
| `3-rollback.bat` | 复位 freeform / 分辨率 |
| `focus-scrcpy.ps1` | 把投屏窗口拉到最前 |
| `demo-chrome.png` | **实测截图：任务栏 + Chrome + 设置 + 计算器三窗口** |
| `final-pcmode.png` | Taskbar 满屏截图 |
| `Taskbar-6.2.2.apk` | 桌面壳（已装到手机） |
| `dl-taskbar.js` | 用 Node 下最新版（本机 curl/PowerShell 的 TLS 坏了） |

---

## 8. 一句话
**不用 root、不用改手机设置、不用开发者开关**——一条命令，手机就变成一块能开多窗口的桌面。

---

## 9. 关于「不能全屏 / 窗口不适配」（实测定位）

### 两个不同的现象，两个不同原因

**① 小窗（freeform）有尺寸上限**
`am task resize` 能把任务边界改成 1600×1000，但窗口实际只长到约 **1122×667**——这是 MIUI 在**没有开启系统 freeform 支持**时对小窗的硬限制。所以：
- 拖边缘拉大：到 ~1120 宽就停
- 小窗的"最大化"按钮：没有真正最大化
- 多窗口时每个窗口只能这么大

**② 竖屏锁定的 App 天生无法铺满**
以「设置」为例，`dumpsys window` 里能看到它被系统标记为 `letterBoxed=true`、`port`，即使强制全屏，也只会在 1600×1000 里居中显示一条 **820 宽的竖列**。
Chrome、Edge、视频类这些**支持横屏**的 App，全屏时会按 **1163×727dp（横屏）** 重新布局，真的像 PC 软件。
这不是系统 bug，是 App 自己锁了竖屏。

### 三种解法（按省事程度排序）

**A. 全屏模式（推荐，现在就能用）**
```bat
2-app-full.bat com.android.chrome      :: 不写参数默认 Chrome
```
用 `--windowingMode 1` 在虚拟屏上全屏打开：铺满 1600×1000，横屏 App 自动变桌面布局。
实测截图：`win-fullscreen-mode.png`（Chrome 满屏，标签栏 + 宽版 Google 首页）。

**B. 多窗口 + 平铺（受 ① 的尺寸限制）**
```bat
2-start-pc.bat        :: 桌面 + Taskbar
4-windows.bat         :: 1 列窗口 / 2 平铺 / 3 最大化 / 4 还原
```
平铺效果见 `win-tile.png`。适合"同时看几个东西"，不适合"一个大窗口铺满"。

**C. 要真正的自由窗口 → 开系统 freeform 支持**
开发者选项 →「USB 调试（安全设置）」→ `1-enable-freeform.bat` → 重启。
系统进入 managed freeform 后窗口尺寸/最大化交给系统窗口管理器，才有桌面级行为。
（这条我无法替你点那个开关，`input` 注入也被同一个权限挡住。）

> 如果是竖屏 App 想要"宽效果"：没有好办法，除非用 Linux 桌面（XFCE 里窗口大小随便拉，但跑的是 Linux 版软件）。

---

## 10. 新增脚本

| 文件 | 作用 |
|---|---|
| `2-app-full.bat <包名>` | 在虚拟屏上全屏打开某个 App（`--windowingMode 1`） |
| `open-app.ps1 <包名> [-Windowed]` | 上面那个的实际实现，`-Windowed` = 小窗模式 |
| `4-windows.bat` | 窗口管理菜单：列窗口 / 平铺 / 最大化 / 还原 |
| `pc-win.ps1 list\|max\|tile\|reset` | 命令行版窗口管理（`max` = 用全屏模式重开前台 App） |
| `win-fullscreen-mode.png` | 全屏模式实测截图（Chrome 铺满且布局适配） |
| `win-tile.png` | 四窗口平铺实测截图 |

---

## 11. PC 侧窗口「不能全屏」的真相（已查明）

### 你的屏幕不是 1440×900

| 项 | 实际值 |
|---|---|
| 面板物理分辨率 | **2880 × 1800** |
| Windows 缩放 | **200%**（窗口 DPI = 192） |
| 逻辑分辨率（程序看到的） | 1440 × 900 |

### 所以两件事要说清楚

**① 投屏窗口其实已经铺满了。**
`2-start-pc.bat` 里的 `--window-borderless --window-x 0 --window-y 0 --window-width 1440 --window-height 900` 用的是**逻辑像素**，正好等于整块屏幕，所以开出来就是满屏无边框（证据：`plain-launch.png`，整屏都是手机桌面，没有 Windows 任务栏、没有黑边）。

**② 真正会坏的只有 `Alt+F` / `--fullscreen`。**
scrcpy 5.0.1 在 200% 缩放的机器上切自己的全屏时，会按 2 倍比例渲染并且裁掉四边——看起来就是"放大了、被切了、不能全屏"。之前那份总结里记的"`--fullscreen` 会放大 1.5 倍并四边裁切"，本质就是这个 HiDPI bug（不同缩放下倍率不同）。
**结论：这台机器上别按 Alt+F，用 bat 的窗口参数就对了。**

### 等比铺满：已经是默认行为

虚拟屏 `1600×1000` 和屏幕逻辑尺寸 `1440×900` 都是 **16:10**，scrcpy 按比例缩放 0.9 后正好铺满 —— 无黑边、无裁切、不变形。这也是为什么当初把分辨率做成 16:10 的原因。

### 如果以后换了显示器或改了缩放

改 `2-start-pc.bat` 里这两个数字，填**屏幕的逻辑尺寸**（= 物理分辨率 ÷ 缩放倍数）：

| 物理分辨率 | 缩放 | 该填的值 |
|---|---|---|
| 2880×1800 | 200% | 1440×900（当前） |
| 1920×1080 | 100% | 1920×1080 |
| 2560×1600 | 125% | 2048×1280 |

虚拟屏保持 16:10 比例（如 `1600x1000`、`1920x1200`），PC 侧就永远是等比铺满。

> 注意：`fit-scrcpy.ps1` 那类"外部强制改窗口大小"的做法在 HiDPI 下会让 scrcpy 的渲染比例和窗口脱节（我试过，画面会放大裁切），已经删掉，别再用。

---

## 12. 手机端卡屏 / UI 闪烁（已定位并修好）

### 根因一：Taskbar 把默认桌面抢走了

```
adb shell cmd package resolve-activity -a android.intent.action.MAIN -c android.intent.category.HOME
→ com.farmerbb.taskbar/.activity.HSLActivity   isDefault=true
```

Taskbar 是"次级桌面"（SecondaryHome），在虚拟屏上表现正常，但在手机主屏上等于一个空桌面。
所以**一清后台 / 一按 Home，系统就回到这个空桌面 → 黑屏、卡死、闪一下再回来**。

修复：把默认桌面还原成 MIUI 桌面
```bat
adb shell cmd package set-home-activity com.miui.home/.launcher.Launcher
adb shell am force-stop com.farmerbb.taskbar
```

### 根因二：残留的虚拟屏 + scrcpy server

之前用 `taskkill` 硬杀投屏进程，手机里留下了 **2 个 app_process（scrcpy server）** 和一块 **displayId 12 的孤儿虚拟屏**——系统一直在多合成一块屏，掉帧和闪烁就是这么来的。

修复：杀掉残留 + 用 `stop-pc.bat` 优雅收工。

### 现在的规矩

| 脚本 | 行为 |
|---|---|
| `2-start-pc.bat` | **不再启动 Taskbar**（改用 Chrome），不会再抢默认桌面 |
| `stop-pc.bat` | 关窗口 → 手机端 `pkill -f com.genymobile.scrcpy` → 检查只剩 displayId 0 |

实测：start 后 `displayId 0 + 13`、HOME 仍是 MIUI；stop 后只剩 `displayId 0`、scrcpy 已退出。

### 如果还偶发

重启一次手机最彻底（SurfaceFlinger 和桌面状态会全清）。Taskbar 现在已经用不上了，想彻底避免复发可以直接卸载：
```bat
adb -d uninstall com.farmerbb.taskbar
```

---

## 13. 真 Linux 桌面（XFCE）——「PC 样式 / 鼠标拖窗口」的正解

Android 的小窗（freeform）天生没有窗口管理能力：没有标题栏拖拽、没有最大化吸附、还被 MIUI 限到 70% 尺寸。
所以第二层方案是**在手机里跑一个真正的 X11 桌面**，PC 侧只是把它全屏显示出来。

### 装了什么（都在手机上，无需 root）

| 组件 | 版本 / 说明 |
|---|---|
| Termux | v0.118.3（GitHub 调试版，`debuggable` 所以电脑可以用 `run-as` 直接驱动它） |
| Termux:X11 | nightly（把 X11 画面渲染到 Android surface） |
| XFCE | 4.20（xfwm4 窗口管理器 + xfce4-panel 任务栏 + Thunar 文件管理器 + 终端） |
| 下载源 | 换成了清华镜像（官方源手机上只有 130KB/s） |

### 一键启动

```bat
2-start-pc.bat          :: 先开虚拟屏（2880x1800，1:1 像素）
5-xfce.bat              :: 再开 XFCE 桌面，全屏投到显示器
stop-xfce.bat           :: 只关桌面
stop-pc.bat             :: 全收（关窗口 + 杀 server + 清虚拟屏）
```

实测截图：`xfce-final.png`（应用菜单 / 桌面图标 / 底部任务栏，无 Android 导航栏、无额外按键条）

### 现在能做到的（这才是"像 PC"）

- **鼠标拖标题栏移动窗口**，拖边缘缩放，双击标题栏最大化
- **右键桌面**出菜单；右键窗口标题栏有 最大化/最小化/移到工作区
- 底部 **xfce4-panel 任务栏**，窗口列表、时钟、系统托盘
- 多工作区（Ctrl+Alt+左右）、Alt+Tab 切换
- 里面跑的是 Linux 软件：Thunar、终端、以后可以装 LibreOffice / Firefox / GIMP

### 已经踩平的坑

| 坑 | 处理 |
|---|---|
| Termux:X11 底部一条 ESC/CTRL/ALT 虚拟按键条盖住任务栏 | 写 `shared_prefs` 把 `showAdditionalKbd=false`、`fullscreen=true` |
| 第一次启动弹「允许发送通知」挡住桌面 | `am force-stop` 后重启 Activity 解决（`pm grant` 被 MIUI 拒了） |
| 虚拟屏为空会被回收 | `2-start-pc.bat` 里始终带 `--start-app` |

### 还没做的（下一步）

1. **中文字体**：LXDE/XFCE 里中文会显示成方块，需要往 `$PREFIX/share/fonts/TTF/` 塞一个中文字体（Windows 的 simhei.ttf）
2. **浏览器**：`pkg install firefox`（约 100MB）
3. 面板默认图标偏小，可以右键面板 → 添加「窗口按钮」让它更像任务栏

### 两套东西可以共存

- **Android 应用**：虚拟屏上单独开（`2-app-full.bat 包名` / `open-app.ps1`），适配问题依旧
- **Linux 应用**：XFCE 桌面里随便开，窗口行为完全正常
