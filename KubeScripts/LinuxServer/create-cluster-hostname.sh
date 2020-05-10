# vmtemplate clusterprefix clonevmid startvmid noofnodes
# titankubetemplate t 100 101 5

kubeJoincommand=""

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

if [ $# -eq 5 ]
then
    currentVMName="$2master"
    vmToClone=$3
    VMID=$4

    # create master
    qm clone $vmToClone $VMID --name $currentVMName --full true # clone VM
    qm set $VMID -onboot 1 # set autostart to true
    qm start $VMID # start VM

    waitForServerToStart $1
    ssh root@$1 "./change-host-name.sh $currentVMName.local" # change host name of prior VM, this is here so we know the prior VM is started

    for ((i = 1; i <= $5; i++)); do       
       VMID=$((VMID+1))   # increment VM id to get a new one
       vmName="$2node$i" # create the current VM name (prefix + node + number)

       qm clone $vmToClone $VMID --name $vmName --full true # clone node    
       qm set $VMID -onboot 1 # set the VM to auto start
       qm start $VMID # start the VM

       waitForServerToStart $1
       echo "Chaning Host Name To $vmName.local"
       
       ssh root@$1 "./change-host-name.sh $vmName.local" # change host name of prior VM, this is here so we know the prior VM is started      
       
    done

    echo "Creating Kubernetes Cluster on Master"
    # Create Kubernetes Cluster
    ssh root@"$2master" "cd kube && ./create-kubernetes-cluster.sh" # create cluster on master

     # get join command from master
    joinCommand=`ssh root@$2master kubeadm token create --print-join-command`
    getKubeCommand "$joinCommand"

     #join nodess do cluster    
    for ((i = 1; i <= $5; i++)); do               
        vmName="$2node$i" # create the current VM name (prefix + worker + number)
        echo "Joining $vmName to cluster"       
        ssh root@$vmName "kubeadm join $kubeJoincommand"        
    done 
    echo "Cluster Creation Is Complete........Both Master and Nodes"
else
    echo "Usage: create-cluster vmtemplate clusterprefix clonevmid startvmid noofnodes (e.g. titankubetemplate t 100 101 5)"
fi