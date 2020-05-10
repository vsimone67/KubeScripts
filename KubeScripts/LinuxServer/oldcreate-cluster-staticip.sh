# templateIp clusterprefix clonevmid startvmid noofnodes startingIp
# 192.168.86.200 t 100 101 5 192.168.86.201

kubeJoincommand=""
NEXTIP=""
nextip(){
        IP=$1
        IP_HEX=$(printf '%.2X%.2X%.2X%.2X\n' `echo $IP | sed -e 's/\./ /g'`)
        NEXT_IP_HEX=$(printf %.8X `echo $(( 0x$IP_HEX + 1 ))`)
        zNEXT_IP=$(printf '%d.%d.%d.%d\n' `echo $NEXT_IP_HEX | sed -r 's/(..)/0x\1 /g'`)
        NEXTIP=${zNEXT_IP}    
    }

getKubeCommand() {
   parameter=$1
   kubeJoincommand=${parameter#*kubeadm join}
}

waitForServerToStart() {
   
   keepRunning=1
   echo "Waiting for $1 to start"
   while [ $keepRunning -eq 1 ]
   do
  
     ping -c1 -W1 -q $1 &>/dev/null
     status=$( echo $? )
     if [[ $status == 0 ]] ; then
        keepRunning=0
     else
        keepRunning=1
     fi
   done

   sleep 5 #wait a few extra seconds to ensure all services are started

}

if [ $# -eq 6 ]
then
    currentVMName="$2master"
    vmToClone=$3
    VMID=$4

    # create master
    qm clone $vmToClone $VMID --name $currentVMName --full true # clone VM
    qm set $VMID -onboot 1 # set autostart to true
    qm start $VMID # start VM

    waitForServerToStart $1
    
    ssh root@$1 "./change-host-info.sh $currentVMName.local $1 $6" # change host name of prior VM, this is here so we know the prior VM is started
    nextip $6

    for ((i = 1; i <= $5; i++)); do       
       VMID=$((VMID+1))   # increment VM id to get a new one
       vmName="$2node$i" # create the current VM name (prefix + node + number)

       qm clone $vmToClone $VMID --name $vmName --full true # clone node    
       qm set $VMID -onboot 1 # set the VM to auto start
       qm start $VMID # start the VM

       waitForServerToStart $1
       
       
       echo "Chaning Host Name To $vmName.local and IP to $NEXTIP"
       ssh root@$1 "./change-host-info.sh $vmName.local $1 $NEXTIP" # change host name of prior VM, this is here so we know the prior VM is started   
       nextip $NEXTIP
       
    done

    echo "Creating Kubernetes Cluster on Master"
    # Create Kubernetes Cluster
     
    ssh root@"$6" "cd kube && ./create-kubernetes-cluster.sh" # create cluster on master
    
     # get join command from master
    joinCommand=`ssh root@$6 kubeadm token create --print-join-command`
    getKubeCommand "$joinCommand"
    nextip $6

     #join nodess do cluster    
    for ((i = 1; i <= $5; i++)); do        
        vmName="$2node$i" # create the current VM name (prefix + worker + number)
        echo "Joining $vmName to cluster IP $NEXTIP"       
        ssh root@$NEXTIP "kubeadm join $kubeJoincommand"        
        nextip $NEXTIP
    done 
    echo "Cluster Creation Is Complete........Both Master and Nodes"
else
    echo "Usage: create-cluster templateIp clusterprefix clonevmid startvmid noofnodes startingIp (e.g. 192.168.86.200 t 100 101 5 192.168.86.201)"
fi