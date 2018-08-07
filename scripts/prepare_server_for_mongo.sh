#!/bin/bash -xe

usage() { echo "Usage: $0 -d <MEMBER_DOMAIN_NAME> -a <0|1> -i <INSTANCE_TYPE>" 1>&2; exit 1; }

while getopts ":d:a:i:" OPTION; do
    case $OPTION in
        d)
            DOMAIN=$OPTARG
            ;;
        a)
            ARBITER=$OPTARG # if we are setting data member or arbiter
            ((a == 0 || a == 1)) || usage
            ;;
        i)
            INSTANCE_TYPE=$OPTARG
            ;;
        *)
            usage
            ;;
    esac
done

if [ -z "$DOMAIN" ]; then
  echo "-d [option] is required"
  usage
fi

if [ -z "$ARBITER" ]; then
  echo "-a [option] is required"
  usage
fi

if [ -z "$INSTANCE_TYPE" ]; then
  echo "-i [option] is required"
  usage
fi

export LANGUAGE=de_DE.UTF-8 && export LANG=de_DE.UTF-8 && export LC_ALL=de_DE.UTF-8 && sudo locale-gen de_DE.UTF-8
sudo dpkg-reconfigure --frontend=noninteractive locales

if [ "$INSTANCE_TYPE" == "m4" ]; then
    DEVICE=/dev/xvdb
    ROOT_PARTITION=/dev/xvda1
    PARTITION=/dev/xvdb1
elif [ "$INSTANCE_TYPE" == "m5" ]; then
    DEVICE=/dev/nvme1n1
    ROOT_PARTITION=/dev/nvme0n1p1
    PARTITION=/dev/nvme1n1p1
else
    echo "Unknown instance $INSTANCE_TYPE. Supported are m4 and m5."
    usage
fi

if [ "$ARBITER" = "0" ]; then
sudo fdisk $DEVICE <<EOF
n
p
1


p
w
EOF

sudo mkfs.xfs -f $PARTITION
sudo mkdir -p /mnt/storage
sudo mount -t xfs $PARTITION /mnt/storage
sudo df -Th /mnt/storage
fi

echo "$DOMAIN" | sudo tee /etc/hostname > /dev/null
sudo hostname -F /etc/hostname
echo -n "127.0.0.1" | sudo tee /etc/hosts > /dev/null
echo -e -n "\t" | sudo tee --append /etc/hosts > /dev/null
echo "$DOMAIN" | sudo tee --append /etc/hosts > /dev/null

sudo touch -a /etc/security/limits.conf

sudo tee -a /etc/security/limits.conf <<EOF
* soft nofile 64000
* hard nofile 64000
* soft nproc 32000
* hard nproc 32000
EOF

sudo touch -a /etc/security/limits.d/90-nproc.conf

sudo tee -a /etc/security/limits.d/90-nproc.conf <<EOF
* soft nproc 32000
* hard nproc 32000
EOF

sudo touch /etc/init.d/disable-transparent-hugepages

sudo tee /etc/init.d/disable-transparent-hugepages <<'EOF'
#!/bin/sh
### BEGIN INIT INFO
# Provides:          disable-transparent-hugepages
# Required-Start:    $local_fs
# Required-Stop:
# X-Start-Before:    mongod mongodb-mms-automation-agent
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Disable Linux transparent huge pages
# Description:       Disable Linux transparent huge pages, to improve
#                    database performance.
### END INIT INFO

case $1 in
  start)
    if [ -d /sys/kernel/mm/transparent_hugepage ]; then
      thp_path=/sys/kernel/mm/transparent_hugepage
    elif [ -d /sys/kernel/mm/redhat_transparent_hugepage ]; then
      thp_path=/sys/kernel/mm/redhat_transparent_hugepage
    else
      return 0
    fi

    echo 'never' > ${thp_path}/enabled
    echo 'never' > ${thp_path}/defrag

    unset thp_path
    ;;
esac
EOF

sudo chmod 755 /etc/init.d/disable-transparent-hugepages
sudo update-rc.d disable-transparent-hugepages defaults

echo -n "LABEL=cloudimg-rootfs" | sudo tee /etc/fstab > /dev/null
echo -e -n "\t" | sudo tee --append /etc/fstab > /dev/null
echo -n "/" | sudo tee --append /etc/fstab > /dev/null
echo -e -n "\t" | sudo tee --append /etc/fstab > /dev/null
echo -n "ext4" | sudo tee --append /etc/fstab > /dev/null
echo -e -n "\t" | sudo tee --append /etc/fstab > /dev/null
echo -n "defaults,noatime,discard" | sudo tee --append /etc/fstab > /dev/null
echo -e -n "\t" | sudo tee --append /etc/fstab > /dev/null
echo -n "0" | sudo tee --append /etc/fstab > /dev/null
echo -e -n "\t" | sudo tee --append /etc/fstab > /dev/null
echo "0" | sudo tee --append /etc/fstab > /dev/null

if [ "$ARBITER" = "0" ]; then
echo -n "$PARTITION" | sudo tee --append /etc/fstab > /dev/null
echo -e -n "\t" | sudo tee --append /etc/fstab > /dev/null
echo -n "/mnt/storage" | sudo tee --append /etc/fstab > /dev/null
echo -e -n "\t" | sudo tee --append /etc/fstab > /dev/null
echo -n "xfs" | sudo tee --append /etc/fstab > /dev/null
echo -e -n "\t" | sudo tee --append /etc/fstab > /dev/null
echo -n "defaults" | sudo tee --append /etc/fstab > /dev/null
echo -e -n "\t" | sudo tee --append /etc/fstab > /dev/null
echo -n "0" | sudo tee --append /etc/fstab > /dev/null
echo -e -n "\t" | sudo tee --append /etc/fstab > /dev/null
echo "0" | sudo tee --append /etc/fstab > /dev/null
fi

sudo touch /var/spool/cron/crontabs/ubuntu

if [ "$ARBITER" = "0" ]; then
sudo tee -a /var/spool/cron/crontabs/ubuntu <<EOF
@reboot /sbin/blockdev --setra 32 $ROOT_PARTITION
@reboot /sbin/blockdev --setra 32 $PARTITION
EOF
else
sudo tee -a /var/spool/cron/crontabs/ubuntu <<EOF
@reboot /sbin/blockdev --setra 32 $ROOT_PARTITION
EOF
fi

sudo chown -R ubuntu:ubuntu /var/spool/cron/crontabs/ubuntu
