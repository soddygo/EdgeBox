#!/bin/bash

function start_display_and_desktop() {
	echo "Starting X11 display server and XFCE4 desktop..."

	# 清理可能存在的X11锁文件和进程
	rm -f /tmp/.X0-lock
	rm -rf /tmp/.X11-unix/X0
	pkill -f "Xvfb :0" || true
	pkill -f "xfce4-session" || true
	pkill -f "dbus-daemon" || true

	# 创建用户运行时目录并设置权限
	USER_ID=$(id -u user)
	mkdir -p /run/user/${USER_ID}
	chmod 700 /run/user/${USER_ID}
	chown user:user /run/user/${USER_ID}

	# 启动 D-Bus 会话 (以 user 用户启动)
	echo "Starting D-Bus session as user..."
	su - user -c "eval \$(dbus-launch --sh-syntax); export DBUS_SESSION_BUS_ADDRESS; echo \"D-Bus session: \$DBUS_SESSION_BUS_ADDRESS\"" &
	sleep 2

	# 启动 D-Bus 系统总线
	echo "Starting D-Bus system bus..."
	mkdir -p /var/run/dbus
	dbus-daemon --system --fork
	sleep 1

	# 启动 PolicyKit 守护进程（配置为不需要认证）
	echo "Starting PolicyKit daemon..."
	/usr/lib/policykit-1/polkitd --no-debug >/var/log/polkitd.log 2>&1 &
	sleep 2

	# 以user用户启动Xvfb
	su - user -c "Xvfb :0 -ac -screen 0 1280x800x16 -retro -dpi 96 -nolisten tcp -nolisten unix >/dev/null 2>&1" &

	# 等待Xvfb启动
	counter=0
	while ! su - user -c "DISPLAY=:0 xdpyinfo" >/dev/null 2>&1; do
		sleep 0.1
		let counter++
		if ((counter > 100)); then
			echo "Failed to start Xvfb"
			return 1
		fi
	done

	# 以user用户启动XFCE4会话和所有必要的守护进程
	su - user -c "
		export DISPLAY=:0
		export XDG_CURRENT_DESKTOP=XFCE
		export XDG_SESSION_DESKTOP=xfce
		export XDG_RUNTIME_DIR=/run/user/${USER_ID}
		export GNOME_KEYRING_CONTROL=/run/user/${USER_ID}/keyring
		export GTK_MODULES=gnome-keyring-pkcs11

		# 启动 gnome-keyring-daemon
		gnome-keyring-daemon --start --components=secrets,ssh,pkcs11 >/dev/null 2>&1 &

		# 启动 PolicyKit 认证代理
		/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 >/var/log/polkit-agent.log 2>&1 &

		# 等待守护进程启动
		sleep 2

		# 启动 XFCE4 会话
		xfce4-session >/dev/null 2>&1
	" &

	echo "X11 display and XFCE4 desktop started successfully"
}

function start_jupyter_server() {
	counter=0
	response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8888/api/status")
	while [[ ${response} -ne 200 ]]; do
		let counter++
		if ((counter % 20 == 0)); then
			echo "Waiting for Jupyter Server to start..."
			sleep 0.1
		fi

		response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8888/api/status")
	done

	cd /root/.server/
	/root/.server/.venv/bin/uvicorn main:app --host 0.0.0.0 --port 49999 --workers 1 --no-access-log --no-use-colors --timeout-keep-alive 640
}

echo "Starting Code Interpreter server..."

# 首先启动显示服务和桌面环境
start_display_and_desktop &

# 设置全局DISPLAY环境变量
export DISPLAY=:0
echo "DISPLAY=:0" >> /etc/environment

# 启动envd和其他服务
/bin/bash -l -c "DISPLAY=:0 /usr/bin/envd" &
start_jupyter_server &
MATPLOTLIBRC=/root/.config/matplotlib/.matplotlibrc jupyter server --IdentityProvider.token="" >/dev/null 2>&1
