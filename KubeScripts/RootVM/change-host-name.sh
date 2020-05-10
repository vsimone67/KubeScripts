if [[ ! $1 ]]; then
	echo "Missing New Host Name"
	exit 1
fi

hostnamectl set-hostname $1
/etc/init.d/network restart