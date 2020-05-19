#!/bin/sh
# 脚本放入到/usr/local/bin
# chmod 755 check_server.sh
# crontab 中添加
source /etc/bashrc

#------监控阈值
DISK_space_warn=90
CPU_load_warn=5
CPU_use_warn=50
MEM_use_warn=95
#SWAP_use_warn=50
Net_SYN_count_warn=200

#判断参数
if [ $# -ne 2 ]; then
    hint_msg="usage: $0 Monitoring_type,Monitoring_type phone,phone,phone"
    echo $hint_msg
	echo "sh $0 disk,cpu,mem,net,io,alive"
    exit -1 
fi

#------监控项
Monitoring_type_tmp=$1
Monitoring_type=$(echo $Monitoring_type_tmp | sed -e 's/,/ /g') 

now=`date -u -d"+8 hour" +'%Y-%m-%d %H:%M:%S'`

#------机器操作系统
OS_version=''
if  grep -q 'CentOS release 6' /etc/redhat-release ; then
	OS_version='CentOS6'
else 
	OS_version='CentOS7'
fi

#------ip地址
localip=`hostname -I | tr ' ' '\n' | grep -E '(^10\.|^172\.(1[6-9]|2[0-9]|31)|^192\.168)' | head -n 1`

send_warning()
{
	发短信的函数
	发送下面的msg变量
}


#------监控CPU相关信息
function sub_cpu(){
	cpu_num=`grep -c 'model name' /proc/cpuinfo`
	
	#------cpu 负载 15 minutes
	load_15=`cat /proc/loadavg  | awk '{print $2}'`
	average_load=`echo "scale=2;a=$load_15/$cpu_num;if(length(a)==scale(a)) print 0;print a" | bc`
	average_int=`echo $average_load | cut -f 1 -d "."`
	if [ "${average_int}" -ge "${CPU_load_warn}" ];then
		msg=${HOSTNAME}" "${localip}" System load average of 15 minutes is "${average_load}" more than "${CPU_load_warn} 
		echo "${now} ${msg}"  >> log
		send_warning
	fi
	
	#------cpu 使用率
	if [ ${OS_version} == 'CentOS6' ];then
		cpu_idle=`top -b -n 1 | grep Cpu | awk '{print $5}' | cut -f 1 -d "."`
	else
		cpu_idle=`top -b -n 1 | grep Cpu | awk '{print $8}' | cut -f 1 -d "."`
	fi
	CPU_use=`expr 100 - $cpu_idle`
	if [ "${CPU_use}" -ge "${CPU_use_warn}" ];then
		msg=${HOSTNAME}" "${localip}" CPU utilization is "${CPU_use}"% more than "${CPU_use_warn}"%" 
		echo "${now} ${msg}"  >> log
		send_warning		
	fi	
}

#------监控内存
function sub_mem(){
	MEM_use=`free | grep "Mem" | awk '{printf("%d", $3*100/$2)}'`
	
	if [ $MEM_use -ge $MEM_use_warn ];then
		msg=${HOSTNAME}" "${localip}" Mem_used:"${MEM_use}"% more than "${MEM_use_warn}"%"
		echo "${now} ${msg}"  >> log
		send_warning
	fi
	#SWAP有很多环境为0 例如在AWS云，腾讯云上
	#SWAP_use=`free | grep "Swap" | awk '{printf("%d", $3*100/$2)}'`
	#if [ $SWAP_use -ge $SWAP_use_warn ];then
	#
	#	send_warning
	#fi 
}

  
#------监控硬盘空间
function sub_disk(){
	#[注意这里用df -P]
	for DISK_space in `df -P | grep /dev | grep -v -E '(tmp|boot)' | awk '{print $5}' | cut -f 1 -d "%" ` 
	do
		if [ $DISK_space -ge "${DISK_space_warn}" ]; then
			msg=${HOSTNAME}" "${localip}" Hard disk space :"${DISK_space}"% more than "${DISK_space_warn}"%"
			echo "${now} ${msg}"  >> log
			send_warning
		fi
	done
}

#------监控网络相关
function sub_net(){

	#------syn 半连接数
	Net_SYN_count=`ss -an | grep -ic syn`
	if [ "${Net_SYN_count}" -ge "${Net_SYN_count_warn}" ]; then
		msg=${HOSTNAME}" "${localip}" Net SYN count :"${Net_SYN_count}" more than "${Net_SYN_count_warn}
		echo "${now} ${msg}"  >> log
		send_warning
	fi
}

#------监控项
for type in $Monitoring_type
do
	[ "${type}" == 'disk' ] && sub_disk
	[ "${type}" == 'cpu' ] && sub_cpu
	[ "${type}" == 'mem' ] && sub_mem
	[ "${type}" == 'net' ] && sub_net
	[ "${type}" == 'io' ] && sub_io
	#[ "${type}" == 'alive' ] && sub_alive
done 


#判断端口是否通 也是判断是否alive的
#!/bin/bash
#Alive=`echo -e "\n" | telnet  192.168.1.30 22 | grep Connected | wc -l`
#if [ "$Alive" == 1 ];then
#        echo "0"    #如果JG等于1，端口为通，输出0
#else 
#        echo "1"    #如果JG等于0，端口不通，输出1
#fi