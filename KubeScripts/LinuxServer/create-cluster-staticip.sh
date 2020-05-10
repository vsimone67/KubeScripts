#!/bin/bash

nextip(){
    IP=$1
    IP_HEX=$(printf '%.2X%.2X%.2X%.2X\n' `echo $IP | sed -e 's/\./ /g'`)
    NEXT_IP_HEX=$(printf %.8X `echo $(( 0x$IP_HEX + 1 ))`)
    NEXT_IP=$(printf '%d.%d.%d.%d\n' `echo $NEXT_IP_HEX | sed -r 's/(..)/0x\1 /g'`)
    echo "$NEXT_IP"
}

getKubeCommand() {
   parameter=$1
   kubeJoincommand=${parameter#*kubeadm join}
   echo "$kubeJoincommand"
}

waitForServerToStart() {
   
   keepRunning=1
   echo "Waiting for $1 to start"
   while [ $keepRunning -eq 1 ]
   do
 
     if ping $1 -c 1 -W 1 -q > /dev/null; then
        keepRunning=0
     else
        keepRunning=1
     fi
   done

   sleep 5 #wait a few extra seconds to ensure all services are started

}

usage() {
    echo "Usage: create-cluster-staticip -t <TEMPLATE IP> -s <START IP OF CLUSTER> -p <HOST PREFIX> -i <TEMPLATE ID> -u <NEW TEMPLATE ID> -n <NUMBER OF NODES>"
    echo "create-cluster-staticip.sh -t 192.168.86.200 -s 192.168.86.201 -p K8 -i 400 -u 500 -n 3"
}


cloneVM() {
    local vmName=$1
    local vmTemplateId=$2
    local vmId=$3
    local templateIp=$4
    local newIp=$5

    #echo "Debug Info VM $vmName Template ID $vmTemplateId VMID $vmId Template IP $templateIp NewIp $newIp"
    echo "Creating VM $vmName"
    qm clone $vmTemplateId $vmId --name $vmName --full true > /dev/null # clone VM
    qm set $vmId -onboot 1 > /dev/null # set autostart to true
    qm start $vmId # start VM

    waitForServerToStart $templateIp
    echo "Changing IP to $newIp"
    ssh root@$templateIp "./change-host-info.sh $vmName.local $templateIp $newIp" # change host name of prior VM, this is here so we know the prior VM is started
    waitForServerToStart $newIp # Make sure new IP address has been updated
}

createCluster() {
    echo "Creating Kubernetes Cluster on Master IP: $1"
    # Create Kubernetes Cluster
     
    ssh root@$1 "cd kube && ./create-kubernetes-cluster.sh" &> /dev/null # create cluster on master ***** ADDED &> /dev/null TO SUPRESS OUTPUT, IF ERRORS REMOVE IT**************
    
}

getJoinCommand() {
     # get join command from master
    joinCommand=`ssh root@$1 kubeadm token create --print-join-command`
    echo "$joinCommand"
}
# ****************** Script starts here ******************

if [ $# -ne 12 ]
then    
    usage
    exit 1
fi


while getopts "t:s:p:i:u:n:" option
do
case "$option"
in
    t) TEMPLATEIP="$OPTARG";;
    s) STARTIP="$OPTARG";;
    p) PREFIX="$OPTARG";;
    i) TEMPLATEID="$OPTARG";;
    u) NEWVMID="$OPTARG";;
    n) NUMBEROFNODES="$OPTARG";;        
    :) echo "Missing option argument for -$OPTARG" >&2; exit 1;;
    *) echo "Unimplemented option: -$OPTARG" >&2; exit 1;;
    
esac
done

echo "Creating Master"
# Start cloning VM's
ip=$STARTIP 
# Creating Master
cloneVM $PREFIX"master" $TEMPLATEID $NEWVMID $TEMPLATEIP $ip

VMID=$NEWVMID

echo "Creating master on $STARTIP"

createCluster $STARTIP

echo "Creating Nodes"
# Creating Nodes
for ((i=1; i <= $NUMBEROFNODES; i++)); do 
    ip=$(nextip $ip) #increment IP to next one
    VMID=$((VMID+1))   # increment VM id to get a new one
    vmName=$PREFIX"node"$i # create the current VM name (prefix + node + number)
    cloneVM $vmName $TEMPLATEID $VMID $TEMPLATEIP $ip
    echo "Joining $vmName to cluster IP $STARTIP"       
    ssh root@$ip "kubeadm join $kubeJoincommand"      
done

joinCommand=$(getJoinCommand $STARTIP)
ip=$STARTIP 

# Joining Nodes To Cluster
for ((i=1; i <= $NUMBEROFNODES; i++)); do 
    ip=$(nextip $ip) #increment IP to next one    
    vmName=$PREFIX"node"$i # create the current VM name (prefix + node + number)    
    echo "Joining $vmName to cluster IP $STARTIP"       
    ssh root@$ip $joinCommand
done

echo "The Cluser Has Been Created...."
