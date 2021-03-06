#!/bin/sh
#
#迅雷远程 Xware V1 守护进程脚本
#脚本版本：2016-12-22-001
#改进作者：泽泽酷儿
#1.本脚本仅适用于迅雷远程V1系列，启动时自动生成守护进程；使用者需自行手动设置自启动。直接运行命令为：sh /脚本路径/脚本名称；
#2.可自动判断迅雷远程的关键进程崩溃情况，并自动重启；
#3.适当限制线程数量区间，避免迅雷远程反复重启，避免设备 CPU 负载过大；
#4.添加日志循环清空重写指令，避免日志叠加写入，避免浪费闪存空间，影响闪存寿命；
#5.可自定义命令循环周期；
#6.支持自动安装迅雷远程 Xware V1。只要把脚本的安装路径设置正确，运行脚本即可自动完成迅雷远程安装并启动守护进程。激活码的中文提示信息见日志；
#
SCRIPTS_DIR="/jffs/scripts"																						#常规脚本保存路径，不可以自定义
INSTALL_DIR=$(var=`find /jffs -name portal`;echo ${var%/portal})												#自动识别 /jffs 分区的迅雷安装路径，无需自定义
LOCAL_FILE="$(basename "$0")"																					#本脚本的文件名称，读取名称，不可以自定义
LOCAL_DIR="$(cd "$(dirname "$0")"; pwd)"																		#本脚本的保存路径，读取路径，不可以自定义
CYCLE_1="15"																									#本脚本的循环执行周期数量
CYCLE_UNIT="m"																									#本脚本的循环执行周期单位(秒单位为s，分钟单位为m，小时单位为h)
if [ "$INSTALL_DIR" = "/jffs/.koolshare/thunder" ] || [ "$INSTALL_DIR" = "/koolshare/thunder" ]; then
	STATE_TYPE="1"																								#Koolshare 软件中心版安装状态
	LOG_DIR="/tmp"
	if [ $(dbus list thunder_basic_CYCLE_1) ] && [ $(dbus list thunder_basic_CYCLE_UNIT) ]; then
		CYCLE_1=$thunder_basic_CYCLE_1
		CYCLE_UNIT=$thunder_basic_CYCLE_UNIT
	fi
else
	STATE_TYPE="2"																								#自行安装状态
	LOG_DIR="$(cd "$(dirname "$0")"; pwd)"																		#日志保存路径，可以自定义
fi
LOG_FILE="${LOCAL_FILE%.*}.log"																					#日志文件名称，不可以自定义
LOG_FULL="${LOG_DIR}"/"${LOG_FILE}"																				#日志文件完整路径
CYCLE_UNIT_zh="分钟"
if [ $CYCLE_UNIT = "h" ]; then
	CYCLE_UNIT_zh="小时"
elif [ $CYCLE_UNIT = "s" ]; then
	CYCLE_UNIT_zh="秒"
fi
check_autorun()
{
	if [ "$STATE_TYPE" = "2" ]; then
		CWS_X="sh ${LOCAL_DIR}/${LOCAL_FILE} &"
		if [ -f "/usr/bin/dbus" ]; then
			EOC=`dbus list __|grep "${LOCAL_DIR}/"${LOCAL_FILE}""`
			Key1=`dbus list __|grep "${LOCAL_DIR}/"${LOCAL_FILE}""|awk -F = '{print $1}'`	
			Key2=`dbus list __|grep "${LOCAL_DIR}/"${LOCAL_FILE}""|awk -F = '{print $2}'`
			if [ "${EOC}" ]; then
				echo "$(date +%Y年%m月%d日\ %X)： 存在默认自启动方案，正在删除该方案……"
				dbus remove "${Key1}" "${Key2}"
			fi
		fi
		if [ -f "${SCRIPTS_DIR}/wan-start" ]; then
			CWS=`cat ${SCRIPTS_DIR}/wan-start|grep "${CWS_X}"`
			if [ -z "${CWS}" ]; then
				echo "$(date +%Y年%m月%d日\ %X)： 调整自启动方案，启用多线程并发自启动方案……"
				echo -e "${CWS_X}" >> "${SCRIPTS_DIR}/wan-start"
			else
				echo "$(date +%Y年%m月%d日\ %X)： 清除可能引起冲突的自启动命令……"
				sed -i "/"${LOCAL_FILE}"/d" "${SCRIPTS_DIR}/wan-start"
				echo "$(date +%Y年%m月%d日\ %X)： 启用多线程并发自启动方案……"
				echo -e "${CWS_X}" >> "${SCRIPTS_DIR}/wan-start"
			fi
		else
			cat > "${SCRIPTS_DIR}/wan-start" <<EOF
#!/bin/sh
${CWS_X}
EOF
		fi
		chmod 755 "${SCRIPTS_DIR}/wan-start"
		if [ -z "$(dbus list __|grep "${SCRIPTS_DIR}/wan-start")" ]; then
			echo "$(date +%Y年%m月%d日\ %X)： 将多线程并发自启动脚本添加到系统自启动……"
			dbus event onwanstart_wan-start "${SCRIPTS_DIR}/wan-start"
		fi
	fi
}
check_xware_process_quantity()
{
	process_of 'EmbedThunderManager|ETMDaemon|vod_httpserver'|wc -l
}
check_xware_process_details()
{
	echo "******************************    迅雷远程线程详情    ******************************"
	process_of 'EmbedThunderManager|ETMDaemon|vod_httpserver'													#获取迅雷远程相关进程的所有线程详情
	if [ $(check_xware_process_quantity) -lt 10 ]; then
		echo "***************************    迅雷远程的总线程数量：$(check_xware_process_quantity)    ***************************"
	elif [ $(check_xware_process_quantity) -ge 10 ]; then
		echo "**************************    迅雷远程的总线程数量：$(check_xware_process_quantity)    **************************"
	fi
}
check_xware_link_status()
{
	cd $INSTALL_DIR
	rm -rf getsysinfo*
	wget -c -N -q --tries=3 http://127.0.0.1:9000/getsysinfo
	if [ -e "getsysinfo" ]; then
		ACTIVE_CODE=`cut -d '"' -f2 getsysinfo`
		USER_ID=`cut -d '"' -f6 getsysinfo`
		VERSION=`cut -d '"' -f4 getsysinfo`
		if [ $VERSION ]; then
			echo "$(date +%Y年%m月%d日\ %X)： 迅雷远程核心版本号：V$VERSION"
		fi
		if [ $ACTIVE_CODE ]; then
			echo "$(date +%Y年%m月%d日\ %X)： 你的迅雷远程激活码：$ACTIVE_CODE"
			echo "$(date +%Y年%m月%d日\ %X)： 迅雷远程尚未绑定用户及设备，请尽快完成绑定！"
		elif [ $USER_ID ]; then
			echo "$(date +%Y年%m月%d日\ %X)： 设备绑定的账户：$USER_ID"
			echo "$(date +%Y年%m月%d日\ %X)： 迅雷远程与服务器连接正常！"
		elif [ ! $ACTIVE_CODE ] && [ ! $USER_ID ]; then
			echo "$(date +%Y年%m月%d日\ %X)： 迅雷远程与服务器失去响应，正在重启……"
			./portal>/dev/null 2>&1
			check_xware_process_details
			echo "$(date +%Y年%m月%d日\ %X)： 迅雷远程已重启完成！"						
			wget -c -N -q --tries=3 http://127.0.0.1:9000/getsysinfo
			if [ ! $ACTIVE_CODE ] && [ ! $USER_ID ]; then
				echo "$(date +%Y年%m月%d日\ %X)： 迅雷远程服务器运行异常！"
			fi
		fi
	else
		echo "$(date +%Y年%m月%d日\ %X)： 网络连接异常，请检查网络连接状态！"	
	fi
}
create_xware_guard_monitor()
{
	cd /tmp
	cat > "check_xware_guard.sh" <<EOF
#!/bin/sh
#
check_xware_guard()
{
while true; do
	sleep 1m
	COUNT_xware_guard=\`ps|grep -E "${LOCAL_FILE}"|grep -v grep|wc -l\`
	PID_xware_guard=\`ps|grep -E "${LOCAL_FILE}|sleep ${CYCLE_1}${CYCLE_UNIT}"|grep -v grep|awk '{print \$1}'\`
	if [ "\${COUNT_xware_guard}" -gt "1" ]; then
		rm -rf "${LOG_FULL}"
		echo "\$(date +%Y年%m月%d日\ %X)： 守护进程线程过多，正在重启守护进程……"
		kill \${PID_xware_guard}
		sh ${LOCAL_DIR}/${LOCAL_FILE}
	elif [ "\${COUNT_xware_guard}" -eq "0" ]; then
		rm -rf "${LOG_FULL}"
		echo "\$(date +%Y年%m月%d日\ %X)： 守护进程运行异常，正在重启守护进程……"
		sh ${LOCAL_DIR}/${LOCAL_FILE}
	fi
done
}
check_xware_guard>>${LOG_FULL} 2>&1 &
EOF
	chmod 755 "check_xware_guard.sh"
}
check_xware_guard_process()
{
	create_xware_guard_monitor
	COUNT_check_xware_guard=`process_of check_xware_guard|wc -l`
	if [ "${COUNT_check_xware_guard}" -eq "0" ]; then
		sh check_xware_guard.sh
	fi
}
download_script()
{
	cd $INSTALL_DIR
	script=$(echo "$@" | awk '{ print substr($0, index($0,$5)) }');
	for i in $script; do
		wget -c -N -q --tries=3 --timeout=15 ftp://koolshare:koolshare@andywoo.vicp.cc/sda1/Scripts/$i
		MD5_1=`md5sum $(ls|grep xunlei-)|cut -d ' ' -f1|tr '[a-z]' '[A-Z]'`
		MD5_2=`ls|grep xunlei-|awk -F _ '{print $2}'|cut -d '.' -f1`
		if [ -e $i ]; then
			if [ $MD5_1 != $MD5_2 ]; then
				echo "$(date +%Y年%m月%d日\ %X)： 已下载新的文件！"
				echo "$(date +%Y年%m月%d日\ %X)： MD5 校验不一致，请检查网络连接状态后重试！"
				rm -rf $i
			else
				echo "$(date +%Y年%m月%d日\ %X)： 已下载新的文件！"
				echo "$(date +%Y年%m月%d日\ %X)： MD5 校验一致！"
			fi
		else
			echo "$(date +%Y年%m月%d日\ %X)： 网络连接存在问题或服务器上无相应文件！"
		fi			
	done
}	
auto_upgrade_script()
{
	cd ${LOCAL_DIR}
	echo "$(date +%Y年%m月%d日\ %X)： 正在连接服务器，检查更新脚本……"
	download_script xunlei-*.sh
	if [ -e xunlei-*.sh ]; then
		if [ $(diff xunlei-*.sh ${LOCAL_FILE} -q|grep -q differ && echo 1 || echo 0) -eq 1 ]; then
			echo "$(date +%Y年%m月%d日\ %X)： 正在更新新版脚本……"
			mv -f xunlei-*.sh ${LOCAL_FILE}
			chmod +x ${LOCAL_FILE}
			echo "$(date +%Y年%m月%d日\ %X)： 正在重新运行脚本……"
			exec ./${LOCAL_FILE}
		elif [ $(diff xunlei-*.sh ${LOCAL_FILE} -q|grep -q differ && echo 1 || echo 0) -eq 0 ]; then
			echo "$(date +%Y年%m月%d日\ %X)： 脚本版本未更新！"
			rm -rf xunlei-*.sh
			echo "$(date +%Y年%m月%d日\ %X)： 继续运行当前脚本……"
			check_xware>>"${LOG_FULL}" 2>&1
		fi
	else
			echo "$(date +%Y年%m月%d日\ %X)： 继续运行当前脚本……"
			check_xware>>"${LOG_FULL}" 2>&1
	fi
}
process_of()
{
	process=$(echo "$@" | awk '{ print substr($0, index($0,$5)) }');
	for i in $process; do
		ps|grep -E $i|grep -v grep
	done
}
check_xware()
{
	if [ "$STATE_TYPE" = "2" ]; then
		echo "$(date +%Y年%m月%d日\ %X)： 已检测到自行安装的迅雷远程，正在启动插件……"
	elif [ "$STATE_TYPE" = "1" ]; then
		echo "$(date +%Y年%m月%d日\ %X)： 已检测到 Koolshare 梅林固件软件中心的迅雷远程，将优先启动该插件……"
	fi
	echo "$(date +%Y年%m月%d日\ %X)： 迅雷远程的安装路径：\"$INSTALL_DIR\""
	echo "$(date +%Y年%m月%d日\ %X)： 守护进程的名称：\"${LOCAL_DIR}/${LOCAL_FILE}\""
	echo "$(date +%Y年%m月%d日\ %X)： 当前脚本的绝对路径：\"$LOCAL_DIR\"，脚本的文件名称：\"$LOCAL_FILE\""
	echo "$(date +%Y年%m月%d日\ %X)： 导出日志的绝对路径：\"$LOG_DIR\"，日志的文件名称：\"$LOG_FILE\""	
	check_autorun
	COUNT_1=$(check_xware_process_quantity)																		#统计迅雷远程相关进程的总线程数量
	check_xware_process_details
	if [ -e $INSTALL_DIR ]; then
		cd $INSTALL_DIR
		chmod 777 * -R
		if [ -e lib ]; then
			if [ -z "$(process_of 'EmbedThunderManager')" ]||[ -z "$(process_of 'ETMDaemon')" ]||[ -z "$(process_of 'vod_httpserver')" ]; then					#判断迅雷远程关键进程如果没有全部正在运行
				echo "$(date +%Y年%m月%d日\ %X)： 迅雷远程关键进程未运行，正在启动……"
				./portal>/dev/null 2>&1																			#重新启动迅雷远程
				check_xware_process_details
				echo "$(date +%Y年%m月%d日\ %X)： 迅雷远程已启动完成！"
			elif [ "$(process_of 'EmbedThunderManager')" ]&&[ "$(process_of 'ETMDaemon')" ]&&[ "$(process_of 'vod_httpserver')" ]; then							#判断迅雷远程关键进程如果全部正在运行
				if [ "${COUNT_1}" -gt "15" ]; then																#判断迅雷远程线程数量大于15
					echo "$(date +%Y年%m月%d日\ %X)： 迅雷远程线程过多，设备负载过大，正在重启……"
					./portal>/dev/null 2>&1																		#重新启动迅雷远程
					check_xware_process_details
					echo "$(date +%Y年%m月%d日\ %X)： 迅雷远程已重启完成！"
				else
					echo "$(date +%Y年%m月%d日\ %X)： 迅雷远程运行正常！"
				fi
			fi
		elif [ -e portal ]; then
			echo "$(date +%Y年%m月%d日\ %X)： 已检测到迅雷远程安装包，正在进行安装……"
			./portal>/dev/null 2>&1
			check_xware_process_details
			echo "$(date +%Y年%m月%d日\ %X)： 迅雷远程安装完成！"
		else
			echo "$(date +%Y年%m月%d日\ %X)： 迅雷远程程序损坏，请重新安装！"
		fi
	else
		echo "$(date +%Y年%m月%d日\ %X)： 未检测到迅雷远程安装路径！"	
	fi
	check_xware_link_status
	echo "$(date +%Y年%m月%d日\ %X)： 守护进程的检查周期：${CYCLE_1} ${CYCLE_UNIT_zh}，本日志将在 ${CYCLE_1} ${CYCLE_UNIT_zh}后更新！"
}
while true; do
	if [ "$STATE_TYPE" = "2" ]; then
		auto_upgrade_script>>"${LOG_FULL}" 2>&1 &
	elif [ "$STATE_TYPE" = "1" ]; then
		eval `dbus export thunder`																				# 导入skipd中储存的数据
		check_xware>>"${LOG_FULL}" 2>&1 &
	fi
	check_xware_guard_process>>/dev/null 2>&1
	sleep ${CYCLE_1}${CYCLE_UNIT}																				#本脚本的循环执行周期(秒单位为s，分钟单位为m，小时单位为h)
	rm -rf "${LOG_FULL}"																						#清空日志内容(按周期循环重写，日志文件体积不会无限变大。如果需要查看历史日志，本行命令可以删除或用#注释掉)
done &