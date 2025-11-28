#!/bin/bash
# Fcitx5 输入法测试脚本

echo "=========================================="
echo "  Fcitx5 中文输入法诊断工具"
echo "=========================================="

# 1. 检查 fcitx5 进程
echo -e "\n[1] 检查 fcitx5 进程状态："
if pgrep -x fcitx5 > /dev/null; then
    echo "✅ fcitx5 正在运行 (PID: $(pgrep -x fcitx5))"
else
    echo "❌ fcitx5 未运行"
    echo "   尝试启动: fcitx5 -d --replace"
fi

# 2. 检查环境变量
echo -e "\n[2] 检查输入法环境变量："
for var in GTK_IM_MODULE QT_IM_MODULE XMODIFIERS INPUT_METHOD; do
    value=$(printenv $var)
    if [ -n "$value" ]; then
        echo "✅ $var=$value"
    else
        echo "❌ $var 未设置"
    fi
done

# 3. 检查 GTK 配置
echo -e "\n[3] 检查 GTK 配置："
if [ -f ~/.config/gtk-3.0/settings.ini ]; then
    echo "✅ GTK 3.0 配置存在"
    grep "gtk-im-module" ~/.config/gtk-3.0/settings.ini
else
    echo "❌ GTK 3.0 配置不存在"
fi

# 4. 检查 fcitx5 配置文件
echo -e "\n[4] 检查 fcitx5 配置："
if [ -f ~/.config/fcitx5/profile ]; then
    echo "✅ profile 配置存在"
    echo "   默认输入法: $(grep DefaultIM ~/.config/fcitx5/profile | cut -d= -f2)"
else
    echo "❌ profile 配置不存在"
fi

# 5. 检查可用输入法
echo -e "\n[5] 检查可用输入法："
if command -v fcitx5-remote &> /dev/null; then
    echo "可用的输入法："
    fcitx5-remote -a 2>/dev/null || echo "   无法获取输入法列表"
else
    echo "❌ fcitx5-remote 命令不存在"
fi

# 6. 当前输入法状态
echo -e "\n[6] 当前输入法状态："
if command -v fcitx5-remote &> /dev/null; then
    state=$(fcitx5-remote 2>/dev/null)
    case $state in
        1) echo "✅ 输入法已激活（中文模式）" ;;
        2) echo "⚪ 输入法未激活（英文模式）" ;;
        *) echo "❓ 状态未知: $state" ;;
    esac
    
    current_im=$(fcitx5-remote -n 2>/dev/null)
    if [ -n "$current_im" ]; then
        echo "   当前输入法: $current_im"
    fi
else
    echo "❌ 无法检查状态"
fi

# 7. 检查 Chromium 进程环境变量
echo -e "\n[7] 检查 Chromium 进程环境变量："
chromium_pid=$(pgrep -x chromium | head -1)
if [ -n "$chromium_pid" ]; then
    echo "✅ Chromium 正在运行 (PID: $chromium_pid)"
    echo "   输入法环境变量："
    cat /proc/$chromium_pid/environ | tr '\0' '\n' | grep -E "(GTK_IM|QT_IM|XMODIFIERS)" | sed 's/^/   /'
else
    echo "⚪ Chromium 未运行"
fi

# 8. 测试建议
echo -e "\n=========================================="
echo "  测试建议："
echo "=========================================="
echo "1. 在终端中测试："
echo "   gedit  # 打开编辑器，按 Ctrl+Space 切换输入法"
echo ""
echo "2. 重启 Chromium（带完整环境变量）："
echo "   pkill chromium"
echo "   GTK_IM_MODULE=fcitx5 QT_IM_MODULE=fcitx5 XMODIFIERS=@im=fcitx5 chromium &"
echo ""
echo "3. 手动切换输入法："
echo "   fcitx5-remote -t  # 切换激活状态"
echo "   fcitx5-remote -s pinyin  # 切换到拼音"
echo ""
echo "4. 查看详细日志："
echo "   tail -f /var/log/fcitx5.log"
echo "=========================================="

