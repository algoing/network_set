#!/bin/bash
#Filename:test
#set the network

interface_info=/root/interface_info.txt

get_interface_list() {
Interfacelist="`ip addr | egrep "^[2-9]" | awk -F '[: ]' '{print $3}'`"
}

get_Hwaddr() {
Interface=$1
Hwaddr="`ip addr | grep -B 1 ${Interface} | grep "ether" | awk '{print $2}'`"
}

get_interface_info() {
ip addr | egrep "(^[2-9]:|ether)" | awk -F '[: ]' '{if($0 ~ /UP/) print $3":UP";else if($0 ~ /DOWN/) print $3":DOWN";else if($0 ~ /link\/ether/) print $6":"$7":"$8":"$9":"$10":"$11}'| awk '/eth/{T=$0;next;}{print T,$0}' | awk 'BEGIN{printf "%-20s %-20s %-20s\n","id","interface:status","mac address"}{printf "%-20s %-20s %-20s\n",NR,$1,$2}' > ${interface_info}
}

get_interface_ip() {
Interface=$1
ip_inter="`ifconfig ${Interface} 2>/dev/null | grep "inet addr" | awk -F '[: ]' '{print $13}'`"
netmask_inter="`ifconfig ${Interface} 2>/dev/null | grep "inet addr" | awk -F '[: ]' '{print $19}'`"
}

get_all_ip() {
get_interface_info
get_interface_list
for i in ${Interfacelist};do
	get_interface_ip $i
	/bin/cp -f ${interface_info} ${interface_info}.bak
	if [ -n "${ip_inter}" -a -n "${netmask_inter}" ];then
	cat ${interface_info}.bak | awk -v ip="${ip_inter}" -v netmask=${netmask_inter} -v interface="${i}" 'NR==1{printf "%-20s %-20s %-20s\n",$0,"ip","netmask"} NR>1{if($0 ~ interface) printf "%-20s %-20s %-20s\n",$0,ip,netmask;else print $0}' > ${interface_info}
	fi
done
}

input_interface_ip() {
Interface=$1
read -p "${Interface}:(dhcp or static)(default:static):" Bootproto
Bootproto=${Bootproto:-static}
read -p "${Interface}:onboot(yes or no)(default:yes):" Onboot
Onboot=${Onboot:-yes}
if [ ${Bootproto} == "static" ];then
	read -p "${Interface}:(ip address):" Ipaddr
	read -p "${Interface}:(netmask)(default:255.255.255.0):" Netmask
	Netmask=${Netmask:-255.255.255.0}
	read -p "${Interface}:(gateway)(default:blank):" Gateway
fi
}

set_interface_ifcfg()
{
Interface=$1
cat > /etc/sysconfig/network-scripts/ifcfg-${Interface}.bak << EOF
TYPE=Ethernet
DEVICE=${Interface}
HWADDR=${Hwaddr}
ONBOOT=${Onboot}
NM_CONTROLLED=yes
BOOTPROTO=${Bootproto}
EOF

if [ "${Bootproto}" == "static" ];then
	echo -e "IPADDR=${Ipaddr}\nNETMASK=${Netmask}\nIPV6INIT=no\nUSERCTL=no" >> /etc/sysconfig/network-scripts/ifcfg-${Interface}.bak
	if [ -n "${Gateway}" ];then 
		echo "GATEWAY=${Gateway}" >> /etc/sysconfig/network-scripts/ifcfg-${Interface}.bak
	fi
fi
/bin/cp -f /etc/sysconfig/network-scripts/ifcfg-${Interface}.bak /etc/sysconfig/network-scripts/ifcfg-${Interface}
[ -f /etc/sysconfig/network-scripts/ifcfg-${Interface} ] && echo "${Interface} set done!"
}

change_interface_ifcfg() {
Interface=$1
[ -f /etc/sysconfig/network-scripts/ifcfg-${Interface}.bak ] && cat -n /etc/sysconfig/network-scripts/ifcfg-${Interface}.bak 
read -p "y or input the number to change(y or 1,2,3...):" check
until [ "${check}" == "y" ];do
	read -p "input the new:" Dhcp
	sed -r -i "${check}s/(^.*=).*/\1${Dhcp}/g" /etc/sysconfig/network-scripts/ifcfg-eth1.bak > /dev/null
	[ -f /etc/sysconfig/network-scripts/ifcfg-${Interface}.bak ] && cat -n /etc/sysconfig/network-scripts/ifcfg-${Interface}.bak 
	read -p "input y to ok or input the number to change(y or 1,2,3...):" check
done
/bin/cp -f /etc/sysconfig/network-scripts/ifcfg-${Interface}.bak /etc/sysconfig/network-scripts/ifcfg-${Interface}

}


choice=h
while true;do
read -p "PL-network:" choice
case $choice in 
"q"|"Q")
	exit 2
;;

"p"|"P")
	get_all_ip
	cat ${interface_info}	
;;

"r"|"R")
	/etc/init.d/network restart	
;;

"s"|"S")
	read -p "select the interface you want to set:" Interface
	get_Hwaddr ${Interface}
	input_interface_ip ${Interface}
	set_interface_ifcfg ${Interface}
;;

"c"|"C")
	read -P "select the interface you want to change:" Interface
	change_interface_ifcfg ${Interface}
;;

"h"|"H"|*)
echo "this is help"
echo "q: Quit
p: Print the current interface status
s: Set a interface argv for your select
c: Change a interface argv for your select
s: Restart the network service
h: Print the help"
;;
esac
done

