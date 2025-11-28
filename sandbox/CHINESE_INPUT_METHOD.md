# Docker 虚拟桌面中文输入法配置说明

## 📋 概述

本文档说明了如何在 Docker 容器的 XFCE 虚拟桌面环境中配置中文输入法，特别是确保 Chromium 浏览器能正常使用中文输入。

## 🎯 解决方案架构

采用 **fcitx5 + ibus 桥接** 的架构：

```
Chromium (GTK3 应用)
    ↓ (使用 GTK_IM_MODULE=ibus)
ibus-daemon (输入法桥接)
    ↓ (通过 D-Bus 通信)
fcitx5 (实际的输入法引擎)
    ↓
fcitx5-pinyin (拼音输入法)
```

### 为什么使用 ibus 桥接？

1. **Chromium 对 ibus 的兼容性最好**：Chromium 是基于 GTK3 的，原生支持 ibus
2. **fcitx5 提供更好的中文输入体验**：更智能的拼音输入、云拼音支持
3. **fcitx5 的 ibusfrontend 模块**：允许 fcitx5 通过 ibus 协议与应用通信

## 🔧 关键配置

### 1. 安装必要的软件包

```dockerfile
# Dockerfile 第 25 行
fcitx5 fcitx5-pinyin \
fcitx5-frontend-gtk3 fcitx5-frontend-gtk2 fcitx5-frontend-qt5 \
fcitx5-module-xorg fcitx5-config-qt \
im-config \
ibus ibus-gtk ibus-gtk3 ibus-qt5 \
dbus-x11
```

**关键包说明**：
- `fcitx5-frontend-gtk3`: GTK3 应用（如 Chromium）的输入法前端
- `fcitx5-module-xorg`: X11 支持
- `ibus` + `ibus-gtk3`: ibus 桥接和 GTK3 支持
- `dbus-x11`: D-Bus 会话总线（输入法通信必需）

### 2. 环境变量配置

在多个层级设置环境变量，确保所有应用都能获取：

#### a) 容器级别（Dockerfile ENV）
```dockerfile
# Dockerfile 第 462-467 行
ENV GTK_IM_MODULE=ibus \
    QT_IM_MODULE=ibus \
    XMODIFIERS=@im=ibus \
    INPUT_METHOD=fcitx5 \
    SDL_IM_MODULE=fcitx5 \
    GLFW_IM_MODULE=ibus
```

#### b) 用户级别（.bashrc, .xprofile, environment.d）
```dockerfile
# Dockerfile 第 134-153 行
# .bashrc - 终端会话
# .xprofile - X 会话启动时
# .config/environment.d/fcitx5.conf - systemd 用户环境
```

#### c) Chromium 启动脚本
```dockerfile
# Dockerfile 第 183 行（/usr/bin/chromium-browser-launcher）
# Dockerfile 第 198 行（/usr/local/bin/chromium）
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
```

### 3. fcitx5 配置

#### a) 输入法配置文件（profile）
```ini
# /home/user/.config/fcitx5/profile
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=pinyin

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=pinyin
Layout=

[Behavior]
ActiveByDefault=True
```

#### b) 快捷键配置（config）
```ini
# /home/user/.config/fcitx5/config
[Hotkey/TriggerKeys]
0=Control+space
1=Shift+Control+space

[Behavior]
ActiveByDefault=True
```

#### c) 拼音配置（pinyin.conf）
```ini
# /home/user/.config/fcitx5/conf/pinyin.conf
[PinyinEngine]
CloudPinyinEnabled=False  # 禁用云拼音提示
```

### 4. D-Bus 会话配置

**关键**：输入法框架需要通过 D-Bus 通信。

#### start-up.sh 中的 D-Bus 启动
```bash
# 启动 D-Bus 会话并保存地址
su - user -c "dbus-launch --sh-syntax > /tmp/dbus-session-env"

# 在后续进程中导入 D-Bus 地址
source /tmp/dbus-session-env
```

### 5. 启动顺序

在 `start-up.sh` 中的正确启动顺序：

```bash
1. D-Bus 会话总线
2. PolicyKit 守护进程
3. Xvfb (虚拟显示服务器)
4. ibus-daemon (输入法桥接)
5. fcitx5 (输入法引擎)
6. XFCE4 会话
7. Chromium (由用户启动)
```

## 🐛 常见问题排查

### 问题 1：输入法托盘图标显示但无法切换

**原因**：fcitx5 无法连接到 D-Bus

**解决**：
```bash
# 检查 D-Bus 会话
echo $DBUS_SESSION_BUS_ADDRESS

# 重启输入法
fix-ime
```

### 问题 2：终端可以输入中文，但 Chromium 不能

**原因**：Chromium 进程没有正确的环境变量

**解决**：
```bash
# 使用修复脚本重启 Chromium
fix-ime
```

### 问题 3：fcitx5-remote 报错 "Failed to create dbus connection"

**原因**：D-Bus 会话地址未设置或不正确

**解决**：
```bash
# 查找并设置 D-Bus 地址
DBUS_PID=$(pgrep -u user dbus-daemon | head -1)
export DBUS_SESSION_BUS_ADDRESS=$(grep -z DBUS_SESSION_BUS_ADDRESS /proc/$DBUS_PID/environ | cut -d= -f2-)
```

## 🛠️ 调试工具

容器中包含以下调试脚本：

### 1. `test-ime` - 输入法状态检查
```bash
test-ime
```
输出：
- 输入法进程状态
- 环境变量
- fcitx5 配置
- D-Bus 连接状态

### 2. `fix-ime` - 一键修复
```bash
fix-ime
```
功能：
- 停止所有相关进程
- 重启输入法框架
- 使用正确环境变量启动 Chromium

### 3. `fix-chromium-ime` - Chromium 专用修复
```bash
fix-chromium-ime
```

## 📝 测试步骤

1. 启动容器并连接 VNC
2. 打开终端，运行 `test-ime` 检查状态
3. 打开 Chromium（双击桌面图标）
4. 访问 baidu.com
5. 点击搜索框
6. 按 `Ctrl+Space` 切换输入法
7. 输入拼音（如 `nihao`），应该看到候选词

## 🎉 成功标志

- ✅ 输入法托盘图标显示
- ✅ 按 `Ctrl+Space` 可以切换输入法
- ✅ 终端中可以输入中文
- ✅ Chromium 搜索框可以输入中文
- ✅ VS Code、gedit 等应用可以输入中文

## 📚 技术细节

### GTK_IM_MODULE 的作用

`GTK_IM_MODULE` 告诉 GTK 应用使用哪个输入法模块：
- `GTK_IM_MODULE=ibus`: 使用 ibus 输入法框架
- `GTK_IM_MODULE=fcitx5`: 直接使用 fcitx5（但 Chromium 兼容性差）

### ibus 与 fcitx5 的通信

fcitx5 通过 `ibusfrontend` 模块实现 ibus 协议：
1. 应用通过 ibus 协议请求输入
2. ibus-daemon 将请求转发给 fcitx5
3. fcitx5 处理输入并返回候选词
4. ibus-daemon 将结果返回给应用

### D-Bus 的重要性

D-Bus 是 Linux 桌面环境的消息总线：
- 输入法框架通过 D-Bus 通信
- 没有正确的 `DBUS_SESSION_BUS_ADDRESS`，输入法无法工作
- 每个用户会话需要独立的 D-Bus 会话总线

## 🔗 相关文件

- `Dockerfile`: 第 17-195 行（输入法安装和配置）
- `start-up.sh`: 第 19-108 行（输入法启动）
- `fix-chrome-ime-final.sh`: 修复脚本
- `test-ime.sh`: 诊断脚本

## 📖 参考资料

- [Fcitx5 官方文档](https://fcitx-im.org/wiki/Fcitx_5)
- [IBus 官方文档](https://github.com/ibus/ibus/wiki)
- [Chromium Input Method 支持](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/docs/linux/input_method.md)

