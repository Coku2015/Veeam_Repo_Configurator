#!/bin/bash

if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use root to configure Veeam Hardened Linux Repository"
    exit 1
fi
contact_us="https://blog.backupnext.cloud"

set_text_color(){
    COLOR_RED='\E[1;31m'
    COLOR_GREEN='\E[1;32m'
    COLOR_YELOW='\E[1;33m'
    COLOR_BLUE='\E[1;34m'
    COLOR_PINK='\E[1;35m'
    COLOR_PINKBACK_WHITEFONT='\033[45;37m'
    COLOR_GREEN_LIGHTNING='\033[32m \033[05m'
    COLOR_END='\E[0m'
}

# A set of disks to ignore from partitioning and formatting
vgname="vg_veeam"
lvname="lv_veeam"

clearscreen(){
    local clear_flag=""
    clear_flag=$1
    if [[ ${clear_flag} == "clear" ]]; then
        clear
    fi
    echo ""
    echo "+-----------------------------------------------------------------+"
    echo "|          Veeam Hardened Linux Repository Configurator           |"
    echo "+----------------------------------------------------------------+"
    echo "|  A tool to pre-config Veeam Hardened Linux Repository on Linux  |"
    echo "+-----------------------------------------------------------------+"
    echo "|This tool is tested with CentOS 8.5 RHEL 8.2/8.4/8.5 Ubuntu 20.04|"
    echo "+-----------------------------------------------------------------+"
    echo "|  Intro: ${contact_us}                           |"
    echo "+-----------------------------------------------------------------+"
    echo ""
}

# Check OS
Get_sys_info(){
    release=''
    systemPackage=''
    DISTRO=''
    if grep -Eqi "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        DISTRO='CentOS'
        release="centos"
        systemPackage='yum'
    elif grep -Eqi "centos|red hat|redhat" /etc/issue || grep -Eqi "centos|red hat|redhat" /etc/*-release; then
        DISTRO='RHEL'
        release="redhat"
        systemPackage='yum'
    elif grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        DISTRO='Ubuntu'
        release="ubuntu"
        systemPackage='apt'
    else
        echo "Your OS is not compatible with Veeam Hardened Linux Repository"
        exit 1
    fi
}

# Check system
check_sys(){
	local checkType=$1
	local value=$2
	if [[ ${checkType} == "sysRelease" ]]; then
		if [ "$value" == "$release" ]; then
			return 0
		else
			return 1
		fi
	elif [[ ${checkType} == "packageManager" ]]; then
		if [ "$value" == "$systemPackage" ]; then
			return 0
		else
			return 1
		fi
	fi
}

Press_configure(){
    echo ""
    echo -e "${COLOR_GREEN}Press any key to configure...or Press Ctrl+c to cancel${COLOR_END}"
    OLDCONFIG=`stty -g`
    stty -icanon -echo min 1 time 0
    dd count=1 2>/dev/null
    stty ${OLDCONFIG}
}

Press_post_configure(){
    echo ""
    echo -e "Please continue your configuration on VBR console"
    echo -e "${COLOR_GREEN}Press any key to disable Veeam User: ${set_vbruser}...or Press Ctrl+c to cancel${COLOR_END}"
    OLDCONFIG=`stty -g`
    stty -icanon -echo min 1 time 0
    dd count=1 2>/dev/null
    stty ${OLDCONFIG}    
}

scan_for_new_disks() {
    # Looks for unpartitioned disks
    declare -a RET
    DEVS=($(ls -1 /dev/sd*|egrep -v "[0-9]$"))
    for DEV in "${DEVS[@]}";
    do
        # Check each device if there is a "1" partition.  If not,
        # "assume" it is not partitioned.
        if [ ! -b ${DEV}1 ];
        then
            RET+="${DEV} "
        fi
    done
    echo "${RET}"
}

add_new_disks() {
    diskselection=${1}
    # Looks for unpartitioned disks
    declare -a RET
    DEVS=($(ls -1 /dev/sd*|egrep -v "[0-9]$"))
    for DEV in "${DEVS[@]}";
    do
        # Check each device if there is a "1" partition.  If not,
        # "assume" it is not partitioned.
        if [ ! -b ${DEV}1 ] && [[ $diskselection =~ ${DEV: 6} ]];
        then
            RET+="${DEV} "
        fi
    done
    echo "${RET}"
}

is_partitioned() {
# Checks if there is a valid partition table on the specified disk
    OUTPUT=$(sfdisk -l ${1} 2>&1)
    grep "No partitions found" "${OUTPUT}" >/dev/null 2>&1
    return "${?}"       
}

do_partition() {
    parted ${1} mklabel gpt >/dev/null 2>&1
    parted ${1} mkpart vbrrepo 1 100% >/dev/null 2>&1
}

has_filesystem() {
    DEVICE=${1}
    OUTPUT=$(file -L -s ${DEVICE})
    grep filesystem <<< "${OUTPUT}" > /dev/null 2>&1
    return ${?}
}

add_to_fstab() {
    UUID=${1}
    set_path=${2}
    FS_TYPE=${3}
    grep "${UUID}" /etc/fstab >/dev/null 2>&1
    if [ ${?} -eq 0 ];
    then
        echo "Not adding ${UUID} to fstab again (it's already there!)"
    else
		if (check_sys sysRelease centos) || (check_sys sysRelease redhat); then
			LINE="UUID=\"${UUID}\"\t${set_path}\t${FS_TYPE}\tdefaults\t0 0"
        elif check_sys sysRelease ubuntu; then
			LINE="/dev/disk/by-uuid/${UUID}\t${set_path}\t${FS_TYPE}\tdefaults\t0 0"
        fi
        echo -e "${LINE}" >> /etc/fstab
    fi
}

# Random password
randstr(){
	index=0
	strRandomPass=""
	for i in {a..z}; do arr[index]=$i; index=`expr ${index} + 1`; done
	for i in {A..Z}; do arr[index]=$i; index=`expr ${index} + 1`; done
	for i in {0..9}; do arr[index]=$i; index=`expr ${index} + 1`; done
	for i in {1..12}; do strRandomPass="$strRandomPass${arr[$RANDOM%$index]}"; done
	echo $strRandomPass
}

get_ip(){
    local ip=`ip addr show |grep "inet " |grep -v 127.0.0. |head -1|cut -d" " -f6|cut -d/ -f1`
    echo ${ip}
}

ready_for_vbr_console(){
    SERVER_IP=$(get_ip)
    clearscreen
    echo "Congratulations, pre-configure completed!"
    echo -e "========================= Your Server Setting ========================="
    echo -e "Your Server IP        : ${COLOR_GREEN}${SERVER_IP}${COLOR_END}"
    echo -e "Veeam Repo Username   : ${set_vbruser}"
    echo -e "Veeam Repo Password   : ${set_vbrpass}"
    echo -e "Veeam Repo Path       : ${set_path}"
    echo "======================================================================="
}

finish_task(){
    clearscreen "clear"
    echo "Congratulations, your Repository is safe now!"
    echo "Please disable SSH service from Linux Console!"    
}

Main_configure(){
    partitions=""
    for DISK in "${DISKS[@]}";
    do
        is_partitioned ${DISK}
        if [ ${?} -ne 0 ];
        then
            echo "${DISK} is not partitioned, partitioning"
            do_partition ${DISK}
        fi
        PARTITION=$(fdisk -l ${DISK} | grep -A 1 Device | tail -n 1 | awk '{print $1}')
        has_filesystem ${PARTITION}
        if [ ${?} -ne 0 ];
        then
            echo "Creating LVM PV"
            pvcreate ${PARTITION}
        fi
        partitions="$partitions ${PARTITION}"
    done
    vgcreate $vgname $partitions
    lvcreate -l +100%free -n $lvname $vgname
    lvpath="/dev/${vgname}/${lvname}"
    mkfs.xfs -b size=4096 -m reflink=1,crc=1 $lvpath
    mkdir $set_path
    UUID=($(blkid -s UUID -u filesystem /dev/vg_veeam/lv_veeam -o value))
    add_to_fstab "${UUID}" "${set_path}" "xfs"
    echo "Mounting volume $lvpath on $set_path"
    sleep 15
    mount "$set_path"
    useradd -m ${set_vbruser}
    echo ${set_vbruser}:${set_vbrpass} | chpasswd
    chown -R ${set_vbruser}:${set_vbruser} $set_path
    chmod 700 $set_path
    mkdir -p /opt/veeam/transport/certs
    chown ${set_vbruser}:${set_vbruser} /opt/veeam/transport/certs
    chmod 770 /opt/veeam/transport/certs
    echo "${set_vbruser} ALL=(ALL:ALL) ALL" >> /etc/sudoers
    ready_for_vbr_console
}

Post_configure(){
    sed -i "/${set_vbruser} ALL=(ALL:ALL) ALL/d" /etc/sudoers
    passwd -l ${set_vbruser}
    echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_all
    finish_task
}
set_text_color
cur_dir=$(pwd)
clearscreen "clear"
Get_sys_info
# lsblk information
echo
echo "=========================================================="
echo -e "${COLOR_PINK}lsblk information:${COLOR_END}"
lsblk
echo "=========================================================="
# User input Repository
echo
echo "=========================================================="
echo -e "${COLOR_PINK}Please input your Repository setting:${COLOR_END}"
DISKS=($(scan_for_new_disks))
echo "Found empty disks are ${DISKS[@]}"
echo "Please select disk to proceed, input format: sdb,sdc,sdd"
read -p "(Default selection is all your empty disks):" set_disk
if [ -z "${set_disk}" ];
then
    echo "Your selection is ${DISKS[@]}" 
else
    DISKS=($(add_new_disks "${set_disk}"))
    echo "Your selection is ${DISKS[@]}"
fi
echo "=========================================================="
def_vbruser="veeamrepo"
echo "Please input username for Veeam Repo User"
read -p "(Default username: ${def_vbruser}):" set_vbruser
[ -z "${set_vbruser}" ] && set_vbruser="${def_vbruser}"
def_vbrpass=`randstr`
echo "Please input password for Veeam Repo User"
read -p "(Default password: ${def_vbrpass}):" set_vbrpass
[ -z "${set_vbrpass}" ] && set_vbrpass="${def_vbrpass}"
def_path="/veeamrepo"
echo "Please input mountpoint for Veeam Repo"
read -p "(Default path: ${def_path}):" set_path
[ -z "${set_path}" ] && set_path="${def_path}"
echo
echo "---------------------------------------"
echo "Veeam Repo Username = ${set_vbruser}"
echo "Veeam Repo Password = ${set_vbrpass}"
echo "Veeam Repo Path = ${set_path}"
echo "---------------------------------------"
echo
Press_configure
Main_configure 2>&1 | tee ${cur_dir}/veeamrepo_configurator.log
Press_post_configure
Post_configure 2>&1 | tee ${cur_dir}/veeamrepo_configurator_post.log

