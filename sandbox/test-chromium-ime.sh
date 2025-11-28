#!/bin/bash
# Chromium 输入法测试脚本

echo "=========================================="
echo "  Chromium 中文输入法修复工具"
echo "=========================================="

# 1. 确保 fcitx5 运行
echo -e "\n[1] 重启 fcitx5..."
pkill fcitx5
sleep 1
fcitx5 -d --replace --verbose default=10 >/var/log/fcitx5.log 2>&1 &
sleep 2

if pgrep -x fcitx5 > /dev/null; then
    echo "✅ fcitx5 已启动 (PID: $(pgrep -x fcitx5))"
else
    echo "❌ fcitx5 启动失败"
    exit 1
fi

# 2. 验证输入法可用
echo -e "\n[2] 检查可用输入法："
fcitx5-remote -a

# 3. 设置环境变量
echo -e "\n[3] 设置输入法环境变量..."
export GTK_IM_MODULE=fcitx5
export QT_IM_MODULE=fcitx5
export XMODIFIERS=@im=fcitx5
export INPUT_METHOD=fcitx5
export DISPLAY=:0

echo "✅ 环境变量已设置"

# 4. 关闭旧的 Chromium 进程
echo -e "\n[4] 关闭旧的 Chromium 进程..."
pkill chromium
sleep 2

# 5. 启动 Chromium
echo -e "\n[5] 启动 Chromium（带完整输入法支持）..."
/usr/bin/chromium \
  --user-data-dir=/home/user/chromium-data \
  --no-sandbox \
  --disable-dev-shm-usage \
  --remote-debugging-port=9222 \
  --remote-debugging-address=0.0.0.0 \
  --no-first-run \
  --no-default-browser-check \
  > /tmp/chromium.log 2>&1 &

# 等待启动
sleep 3

# 6. 验证 Chromium 进程
chromium_pid=$(pgrep chromium | head -1)
if [ -n "$chromium_pid" ]; then
    echo "✅ Chromium 已启动 (PID: $chromium_pid)"
    
    echo -e "\n[6] Chromium 进程环境变量："
    cat /proc/$chromium_pid/environ | tr '\0' '\n' | grep -E "(GTK_IM|QT_IM|XMODIFIERS)" | sed 's/^/   /'
    
    echo -e "\n[7] Chromium 启动日志（最后 10 行）："
    tail -10 /tmp/chromium.log | sed 's/^/   /'
else
    echo "❌ Chromium 启动失败"
    echo -e "\n启动日志："
    cat /tmp/chromium.log
    exit 1
fi

echo -e "\n=========================================="
echo "  测试步骤："
echo "=========================================="
echo "1. 打开 Chromium，访问 baidu.com"
echo "2. 点击搜索框"
echo "3. 按 Ctrl+Space 切换输入法"
echo "4. 输入拼音，应该看到候选词"
echo ""
echo "如果还是不行，查看日志："
echo "  tail -50 /var/log/fcitx5.log"
echo "  cat /tmp/chromium.log"
echo "=========================================="

