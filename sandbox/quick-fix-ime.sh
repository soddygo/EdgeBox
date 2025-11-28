#!/bin/bash
# 快速修复 Chromium 输入法

echo "正在修复 Chromium 输入法..."

# 1. 重启输入法
pkill fcitx5 ibus-daemon chromium
sleep 1

# 2. 启动 ibus（Chromium 更兼容）
ibus-daemon -drx &
sleep 1

# 3. 启动 fcitx5
fcitx5 -d --replace &
sleep 2

# 4. 启动 Chromium
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
chromium &

echo "✅ 完成！请在 Chromium 中测试输入法"
echo "   按 Ctrl+Space 切换输入法"

