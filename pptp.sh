#!/bin/bash
#
# Author:  Monster <18610599620 AT 163.com>
# Blog:  http://www.shaobin.wang
#
# Installs a PPTP VPN-only system for CentOS6、7

# Check if user is root
[ $(id -u) != "0" ] && { echo -e "\033[31mError: You must be root to run this script\033[0m"; exit 1; } 

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
clear
printf "
#######################################################################
#    LNMP/LAMP/LANMP for CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+    #
#            Installs a PPTP VPN-only system for CentOS               #
# For more information please visit http://www.shaobin.wang           #
#######################################################################
"

[ ! -e '/usr/bin/curl' ] && yum -y install curl

VPN_IP=`curl ipv4.icanhazip.com`

VPN_USER="MonsterWang"
VPN_PASS="MonsterWang"

VPN_LOCAL="192.168.0.150"
VPN_REMOTE="192.168.0.151-200"

while :
do
        echo
        read -p "Please input username: " VPN_USER 
        [ -n "$VPN_USER" ] && break
done

while :
do
        echo
        read -p "Please input password: " VPN_PASS
        [ -n "$VPN_PASS" ] && break
done
clear


if [ -f /etc/redhat-release -a -n "`grep ' 7\.' /etc/redhat-release`" ];then
        #CentOS_REL=7
	if [ ! -e /etc/yum.repos.d/epel.repo ];then
		cat > /etc/yum.repos.d/epel.repo << EOF
[epel]
name=Extra Packages for Enterprise Linux 7 - \$basearch
#baseurl=http://download.fedoraproject.org/pub/epel/7/\$basearch
mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=epel-7&arch=\$basearch
failovermethod=priority
enabled=1
gpgcheck=0
EOF
fi
        for Package in wget make openssl gcc-c++ ppp pptpd iptables iptables-services 
        do
                yum -y install $Package
        done
        echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
elif [ -f /etc/redhat-release -a -n "`grep ' 6\.' /etc/redhat-release`" ];then
        #CentOS_REL=6
        for Package in wget make openssl gcc-c++ iptables ppp 
        do
                yum -y install $Package
        done
	sed -i 's@net.ipv4.ip_forward.*@net.ipv4.ip_forward = 1@g' /etc/sysctl.conf
	rpm -Uvh http://poptop.sourceforge.net/yum/stable/rhel6/pptp-release-current.noarch.rpm
	yum -y install pptpd
else
        echo -e "\033[31mDoes not support this OS, Please contact the author! \033[0m"
        exit 1
fi


echo "1" > /proc/sys/net/ipv4/ip_forward

echo 'nameserver 223.5.5.5' >> /etc/resolv.conf
echo 'nameserver 114.114.114.114' >> /etc/resolv.conf

/etc/init.d/network restart

sysctl -p /etc/sysctl.conf

[ -z "`grep '^localip' /etc/pptpd.conf`" ] && echo "localip $VPN_LOCAL" >> /etc/pptpd.conf # Local IP address of your VPN server
[ -z "`grep '^remoteip' /etc/pptpd.conf`" ] && echo "remoteip $VPN_REMOTE" >> /etc/pptpd.conf # Scope for your home network

if [ -z "`grep '^ms-dns' /etc/ppp/options.pptpd`" ];then
  echo "ms-dns 223.5.5.5" >> /etc/ppp/options.pptpd # Aliyun DNS Primary
  echo "ms-dns 114.114.114.114" >> /etc/ppp/options.pptpd # 114 DNS Primary
fi

echo "$VPN_USER pptpd $VPN_PASS *" >> /etc/ppp/chap-secrets

ETH=`route | grep default | awk '{print $NF}'`
[ -z "`grep '1723 -j ACCEPT' /etc/sysconfig/iptables`" ] && iptables -I INPUT 4 -p tcp -m state --state NEW -m tcp --dport 1723 -j ACCEPT
[ -z "`grep 'gre -j ACCEPT' /etc/sysconfig/iptables`" ] && iptables -I INPUT 5 -p gre -j ACCEPT 
iptables -t nat -A POSTROUTING -o $ETH -j MASQUERADE
iptables -I FORWARD -p tcp --syn -i ppp+ -j TCPMSS --set-mss 1356
service iptables save
sed -i 's@^-A INPUT -j REJECT --reject-with icmp-host-prohibited@#-A INPUT -j REJECT --reject-with icmp-host-prohibited@' /etc/sysconfig/iptables 
sed -i 's@^-A FORWARD -j REJECT --reject-with icmp-host-prohibited@#-A FORWARD -j REJECT --reject-with icmp-host-prohibited@' /etc/sysconfig/iptables 
service iptables restart
chkconfig iptables on

service pptpd restart
chkconfig pptpd on
clear

echo -e "You can now connect to your VPN via your external IP \033[32m${VPN_IP}\033[0m"

echo -e "Username: \033[32m${VPN_USER}\033[0m"
echo -e "Password: \033[32m${VPN_PASS}\033[0m"
