# Docker 中文输入法配置变更日志

## 🎯 目标
在 Docker 容器的 XFCE 虚拟桌面中实现中文输入法，特别是确保 Chromium 浏览器能正常使用中文输入。

## ✅ 解决方案
采用 **fcitx5 + ibus 桥接** 架构，利用 Chromium 对 ibus 的原生支持。

---

## 📝 修改清单

### 1. Dockerfile 修改

#### 1.1 安装输入法相关包（第 25 行）
```diff
- fcitx5 fcitx5-pinyin
+ fcitx5 fcitx5-pinyin fcitx5-frontend-gtk3 fcitx5-frontend-gtk2 fcitx5-frontend-qt5 fcitx5-module-xorg fcitx5-config-qt im-config ibus ibus-gtk ibus-gtk3 ibus-qt5 dbus-x11
```

**新增包说明**：
- `fcitx5-frontend-gtk3`: GTK3 前端（Chromium 需要）
- `fcitx5-module-xorg`: X11 支持
- `ibus` + `ibus-gtk3` + `ibus-qt5`: ibus 桥接和前端
- `dbus-x11`: D-Bus X11 集成

#### 1.2 用户环境变量配置（第 133-177 行）
```bash
# .bashrc - 终端会话
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
export INPUT_METHOD=fcitx5

# .xprofile - X 会话启动
# .config/environment.d/fcitx5.conf - systemd 用户环境
# .config/gtk-3.0/settings.ini - GTK3 配置
```

**关键点**：使用 `ibus` 作为前端模块，而不是直接使用 `fcitx5`

#### 1.3 fcitx5 配置文件（第 156-177 行）
- `~/.config/fcitx5/config`: 快捷键（Ctrl+Space）、行为配置
- `~/.config/fcitx5/conf/pinyin.conf`: 禁用云拼音提示
- `~/.config/fcitx5/profile`: 输入法列表（keyboard-us + pinyin）
- `~/.config/gtk-3.0/settings.ini`: GTK3 使用 ibus

#### 1.4 Chromium 启动脚本（第 183、198 行）
```bash
# /usr/bin/chromium-browser-launcher
# /usr/local/bin/chromium
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
export INPUT_METHOD=fcitx5
```

#### 1.5 桌面启动项（第 248、254 行）
```desktop
# chromium.desktop
Exec=env GTK_IM_MODULE=ibus QT_IM_MODULE=ibus XMODIFIERS=@im=ibus /usr/bin/chromium-browser-launcher
```

#### 1.6 容器级环境变量（第 462-467 行）
```dockerfile
ENV GTK_IM_MODULE=ibus \
    QT_IM_MODULE=ibus \
    XMODIFIERS=@im=ibus \
    INPUT_METHOD=fcitx5
```

#### 1.7 D-Bus 配置（第 469-478 行）
- 创建 `/etc/dbus-1/session.d/user-session.conf`
- 允许 user 用户完全访问 D-Bus

#### 1.8 调试脚本（第 439-452 行）
```dockerfile
COPY ./test-ime.sh /usr/local/bin/test-ime
COPY ./test-chromium-ime.sh /usr/local/bin/fix-chromium-ime
COPY ./quick-fix-ime.sh /usr/local/bin/quick-fix
COPY ./fix-chrome-ime-final.sh /usr/local/bin/fix-ime
```

---

### 2. start-up.sh 修改

#### 2.1 D-Bus 会话启动（第 19-27 行）
```diff
- su - user -c "eval $(dbus-launch --sh-syntax); ..."
+ su - user -c "dbus-launch --sh-syntax > /tmp/dbus-session-env"
+ source /tmp/dbus-session-env
```

**关键改进**：保存 D-Bus 会话地址到文件，供后续进程使用

#### 2.2 输入法环境变量（第 58-65 行）
```bash
# 导入 D-Bus 会话地址
source /tmp/dbus-session-env

# 设置输入法环境变量
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
export INPUT_METHOD=fcitx5
```

#### 2.3 输入法启动顺序（第 75-101 行）
```bash
# 1. 启动 ibus-daemon（桥接）
ibus-daemon -drx >/tmp/ibus.log 2>&1 &
sleep 1

# 2. 启动 fcitx5（输入法引擎）
fcitx5 -d --replace >/tmp/fcitx5.log 2>&1 &
sleep 2

# 3. 验证启动成功
pgrep -x fcitx5 && echo 'fcitx5 started successfully'
pgrep -x ibus-daemon && echo 'ibus-daemon started successfully'
```

**关键点**：
- 先启动 ibus-daemon，再启动 fcitx5
- 确保 D-Bus 地址已设置
- 日志输出到 /tmp 便于调试

---

### 3. 新增文件

#### 3.1 test-ime.sh
输入法诊断工具，检查：
- 进程状态（fcitx5, ibus-daemon）
- 环境变量
- D-Bus 连接
- fcitx5 配置

#### 3.2 fix-chrome-ime-final.sh
一键修复脚本，执行：
1. 停止所有相关进程
2. 重启 ibus-daemon 和 fcitx5
3. 使用正确环境变量启动 Chromium

#### 3.3 CHINESE_INPUT_METHOD.md
完整的技术文档，包含：
- 架构说明
- 配置详解
- 问题排查
- 测试步骤

---

## 🔑 关键技术点

### 1. 为什么使用 ibus 桥接？
- Chromium 对 ibus 的兼容性最好（原生支持）
- fcitx5 通过 `ibusfrontend` 模块实现 ibus 协议
- 避免直接使用 `GTK_IM_MODULE=fcitx5`（兼容性差）

### 2. D-Bus 的重要性
- 输入法框架通过 D-Bus 通信
- 必须正确设置 `DBUS_SESSION_BUS_ADDRESS`
- 每个用户会话需要独立的 D-Bus 会话总线

### 3. 环境变量的传递
- 容器级 ENV → 用户级配置 → 启动脚本 → 应用进程
- Chromium 必须在启动时就有正确的环境变量
- 不能依赖桌面环境自动传递

### 4. 启动顺序
```
D-Bus → ibus-daemon → fcitx5 → XFCE → Chromium
```
每一步都依赖前一步的成功启动

---

## 🧪 测试验证

### 终端测试
```bash
# 1. 检查输入法状态
test-ime

# 2. 打开文本编辑器
gedit &

# 3. 输入拼音测试
```

### Chromium 测试
```bash
# 1. 使用修复脚本启动
fix-ime

# 2. 访问 baidu.com
# 3. 点击搜索框
# 4. 按 Ctrl+Space 切换输入法
# 5. 输入拼音（如 nihao）
```

---

## 📊 修改统计

- **Dockerfile**: 约 50 行修改/新增
- **start-up.sh**: 约 20 行修改
- **新增文件**: 4 个（3 个脚本 + 1 个文档）
- **涉及包**: 新增 10+ 个输入法相关包

---

## 🎉 最终效果

✅ 终端可以输入中文
✅ Chromium 可以输入中文
✅ VS Code 可以输入中文
✅ gedit 等 GTK 应用可以输入中文
✅ 输入法托盘图标正常显示
✅ Ctrl+Space 快捷键正常工作

---

## 📚 相关资源

- [Fcitx5 官方文档](https://fcitx-im.org/wiki/Fcitx_5)
- [IBus 官方文档](https://github.com/ibus/ibus/wiki)
- [Chromium Input Method](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/docs/linux/input_method.md)

---

**修改日期**: 2025-11-28
**测试环境**: Debian 12 + XFCE + Chromium
**状态**: ✅ 已验证可用
