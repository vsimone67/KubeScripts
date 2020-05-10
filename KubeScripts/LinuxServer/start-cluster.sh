# startvmid noofnodes
# 100 101 7

if [ $# -eq 2 ]
then   
    
    VMID=$1 # get starting rm to remove
    for ((i = 0; i <= $2; i++)); do       
       qm stop $VMID # stop the VM
       qm destroy $VMID --purge true # destroy the VM
       VMID=$((VMID+1))       
    done

else
    echo "Usage: startvmid noofnodes (e.g. delete-cluster 101 7)"
fi