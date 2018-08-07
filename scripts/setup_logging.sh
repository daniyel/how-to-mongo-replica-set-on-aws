#!/bin/bash -xe
usage() { echo "Usage: $0 -a <0|1> -s <STACK_NAME>" 1>&2; exit 1; }

while getopts ":s:a:" OPTION; do
    case $OPTION in
        s)
            STACK_NAME=$OPTARG
            ;;
        a)
            ARBITER=$OPTARG # if we are setting data member or arbiter
            ((a == 0 || a == 1)) || usage
            ;;
        *)
            usage
            ;;
    esac
done

if [ -z "$STACK_NAME" ]; then
  echo "-s [option] is required"
  usage
fi

if [ -z "$ARBITER" ]; then
  echo "-a [option] is required"
  usage
fi

export LC_ALL=de_DE.UTF-8

sudo mkdir -p /etc/awslogs
sudo touch /etc/awslogs/awslogs.conf
sudo chmod 0644 /etc/awslogs/awslogs.conf

sudo touch /etc/logrotate.d/mongod

sudo apt-get install -y logrotate python-minimal

curl https://s3.amazonaws.com//aws-cloudwatch/downloads/latest/awslogs-agent-setup.py -O
sudo chmod +x ./awslogs-agent-setup.py

if [ "$ARBITER" = "1" ]; then
sudo tee /etc/awslogs/awslogs.conf <<EOF
[general]
state_file = /var/awslogs/state/agent-state

[/var/log/messages]
file = /var/log/messages
log_group_name = ${STACK_NAME}-/var/log/messages
log_stream_name = ${STACK_NAME}
datetime_format = %b %d %H:%M:%S

[/var/log/mongodb/mongod.log]
file = /var/log/mongodb/mongod.log
log_group_name = ${STACK_NAME}-/var/log/mongodb/mongod.log
log_stream_name = ${STACK_NAME}
datetime_format = %a %b %d %H:%M:%S.%f
EOF

sudo tee /etc/logrotate.d/mongod <<'EOF'
/var/log/mongodb/*.log {
    daily
    rotate 5
    compress
    dateext
    missingok
    notifempty
    sharedscripts
    copytruncate
    postrotate
        /bin/kill -SIGUSR1 `cat /var/lib/mongodb/mongod.lock 2> /dev/null` 2> /dev/null || true
    endscript
}
EOF

else

sudo tee /etc/awslogs/awslogs.conf <<EOF
[general]
state_file = /var/awslogs/state/agent-state

[/var/log/messages]
file = /var/log/messages
log_group_name = ${STACK_NAME}-/var/log/messages
log_stream_name = ${STACK_NAME}
datetime_format = %b %d %H:%M:%S

[/mnt/storage/mongodb/logs/mongod.log]
file = /mnt/storage/mongodb/logs/mongod.log
log_group_name = ${STACK_NAME}-/mnt/storage/mongodb/logs/mongod.log
log_stream_name = ${STACK_NAME}
datetime_format = %a %b %d %H:%M:%S.%f
EOF

sudo tee /etc/logrotate.d/mongod <<'EOF'
/mnt/storage/mongodb/logs/*.log {
    daily
    rotate 5
    compress
    dateext
    missingok
    notifempty
    sharedscripts
    copytruncate
    postrotate
        /bin/kill -SIGUSR1 `cat /var/lib/mongodb/mongod.lock 2> /dev/null` 2> /dev/null || true
    endscript
}
EOF

fi

AWS_REGION=$(curl -s 169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//')
sudo ./awslogs-agent-setup.py -n -r $AWS_REGION -c /etc/awslogs/awslogs.conf
