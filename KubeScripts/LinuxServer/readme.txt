Steps to create cluster (the scripts will now dyanmically create the master and nodes based on parameters you pass to the scripts

1) Run delete-cluster (this will stop all running VMS and delete them, this is not needed for a new enviornment)
2) Run create-cluster (either hostname or staticip) (copy the master IP, token, and sha token created when the cluster is created)

*** NOTE *****
Remember under proxmox to name the kube template VM to name.local (e.g. kubetemplate.local).  This will allow proxmox under the server shell to resolve the host name