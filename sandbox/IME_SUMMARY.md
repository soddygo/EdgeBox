# 🎯 Docker 中文输入法配置总结

## 核心架构

```
┌─────────────────────────────────────────────────────────┐
│                    应用层                                │
│  Chromium / VS Code / gedit / 终端                      │
│  (使用 GTK_IM_MODULE=ibus)                              │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│                  ibus-daemon                             │
│  (输入法桥接，Chromium 原生支持)                         │
└────────────────────┬────────────────────────────────────┘
                     │ D-Bus 通信
                     ▼
┌─────────────────────────────────────────────────────────┐
│                   fcitx5                                 │
│  (输入法引擎，通过 ibusfrontend 模块)                    │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│               fcitx5-pinyin                              │
│  (拼音输入法实现)                                        │
└─────────────────────────────────────────────────────────┘
```

## 关键修改点

### 📦 1. 软件包安装 (Dockerfile 第 25 行)

```bash
# 新增包
fcitx5-frontend-gtk3      # GTK3 前端（Chromium 必需）
fcitx5-module-xorg        # X11 支持
ibus + ibus-gtk3          # ibus 桥接
dbus-x11                  # D-Bus X11 集成
```

### 🔧 2. 环境变量 (多处设置)

```bash
export GTK_IM_MODULE=ibus      # 使用 ibus，不是 fcitx5！
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
export INPUT_METHOD=fcitx5
```

**设置位置**：
- Dockerfile ENV (容器级)
- .bashrc / .xprofile (用户级)
- Chromium 启动脚本
- start-up.sh (会话级)

### 🚀 3. 启动顺序 (start-up.sh)

```bash
1. D-Bus 会话总线
   └─> dbus-launch > /tmp/dbus-session-env
   
2. ibus-daemon
   └─> ibus-daemon -drx &
   
3. fcitx5
   └─> fcitx5 -d --replace &
   
4. XFCE 会话
   └─> xfce4-session
```

### 🔑 4. D-Bus 配置 (关键！)

```bash
# start-up.sh 中保存 D-Bus 地址
dbus-launch --sh-syntax > /tmp/dbus-session-env

# 后续进程导入
source /tmp/dbus-session-env
```

**为什么重要**：输入法框架必须通过 D-Bus 通信

## 文件修改清单

| 文件 | 修改内容 | 行数 |
|------|---------|------|
| `Dockerfile` | 安装输入法包 | 第 25 行 |
| `Dockerfile` | 用户环境变量配置 | 第 133-177 行 |
| `Dockerfile` | Chromium 启动脚本 | 第 183, 198 行 |
| `Dockerfile` | 容器环境变量 | 第 462-467 行 |
| `Dockerfile` | 调试脚本复制 | 第 439-452 行 |
| `start-up.sh` | D-Bus 启动 | 第 19-27 行 |
| `start-up.sh` | 输入法启动 | 第 75-101 行 |
| `fix-chrome-ime-final.sh` | 修复脚本 | 新增文件 |
| `test-ime.sh` | 诊断脚本 | 新增文件 |

## 快速使用指南

### 🛠️ 容器内调试命令

```bash
# 检查输入法状态
test-ime

# 一键修复 Chromium 输入法
fix-ime

# 手动重启输入法
killall fcitx5 ibus-daemon
ibus-daemon -drx &
fcitx5 -d &
```

### ✅ 测试步骤

1. **终端测试**
   ```bash
   gedit &
   # 按 Ctrl+Space，输入拼音
   ```

2. **Chromium 测试**
   - 访问 baidu.com
   - 点击搜索框
   - 按 Ctrl+Space
   - 输入拼音（如 nihao）

## 常见问题

### ❌ 问题：Chromium 无法输入中文

**原因**：环境变量未正确传递

**解决**：
```bash
fix-ime
```

### ❌ 问题：fcitx5-remote 报错

**原因**：D-Bus 连接失败

**解决**：
```bash
# 检查 D-Bus 地址
echo $DBUS_SESSION_BUS_ADDRESS

# 重新导入
source /tmp/dbus-session-env
```

### ❌ 问题：输入法托盘图标不显示

**原因**：fcitx5 未启动

**解决**：
```bash
fcitx5 -d --replace &
```

## 技术要点

### 为什么用 ibus 而不是直接用 fcitx5？

| 方案 | Chromium 兼容性 | 说明 |
|------|----------------|------|
| `GTK_IM_MODULE=fcitx5` | ❌ 差 | Chromium 不完全支持 |
| `GTK_IM_MODULE=ibus` | ✅ 好 | Chromium 原生支持 |

### fcitx5 如何与 ibus 通信？

通过 `ibusfrontend` 模块：
1. fcitx5 实现 ibus 协议
2. ibus-daemon 转发请求
3. 应用通过 ibus 获取输入

### D-Bus 的作用？

- 输入法框架的消息总线
- 没有正确的 `DBUS_SESSION_BUS_ADDRESS` 输入法无法工作
- 必须在启动输入法前设置

## 验证清单

- [ ] 安装了所有必需的包（fcitx5, ibus, dbus-x11）
- [ ] 环境变量使用 `GTK_IM_MODULE=ibus`
- [ ] D-Bus 会话正确启动并导出地址
- [ ] ibus-daemon 在 fcitx5 之前启动
- [ ] Chromium 启动时有正确的环境变量
- [ ] 终端可以输入中文
- [ ] Chromium 可以输入中文

## 相关文档

- 📖 [完整技术文档](./CHINESE_INPUT_METHOD.md)
- 📝 [详细变更日志](./CHANGELOG_CHINESE_IME.md)
- 🐛 [调试脚本](./fix-chrome-ime-final.sh)

---

**状态**: ✅ 已验证可用  
**测试日期**: 2025-11-28  
**环境**: Debian 12 + XFCE + Chromium
