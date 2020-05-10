if [ $# -eq 3 ]
then
    hostnamectl set-hostname $1
    oldIp=$2
    newIp=$3
    sed -i "s/${oldIp}/${newIp}/g" /etc/sysconfig/network-scripts/ifcfg-eth0
    reboot
else
    echo "Usage: changehostinfo newHostName oldIpAddress newIpAddress (newhostname, 192.168.86.200 192.168.86.201)"
fi
