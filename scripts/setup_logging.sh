#!/bin/bash -xe

usage() { echo "Usage: $0 [-a <0|1>]" 1>&2; exit 1; }

while getopts ":a:" OPTION; do
    case $OPTION in
        a)
            ARBITER=$OPTARG # if we are setting data member or arbiter
            ((a == 0 || a == 1)) || usage
            ;;
        *)
            usage
            ;;
    esac
done

if [ -z "$ARBITER" ]; then
  echo "-a [option] is required"
  usage
fi

sudo apt-get install -y logrotate

curl https://s3.amazonaws.com//aws-cloudwatch/downloads/latest/awslogs-agent-setup.py -O
sudo chmod +x ./awslogs-agent-setup.py

if [ "$ARBITER" = "1" ]; then
sudo tee /etc/awslogs/awslogs.conf <<'EOF'
[general]
state_file = /var/awslogs/state/agent-state

[/var/log/messages]
file = /var/log/messages
log_group_name = ${AWS::StackName}-/var/log/messages
log_stream_name = ${AWS::StackName}
datetime_format = %b %d %H:%M:%S

[/var/log/mongodb/mongod.log]
file = /var/log/mongodb/mongod.log
log_group_name = ${AWS::StackName}-/var/log/mongodb/mongod.log
log_stream_name = ${AWS::StackName}
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

sudo tee /etc/awslogs/awslogs.conf <<'EOF'
[general]
state_file = /var/awslogs/state/agent-state

[/var/log/messages]
file = /var/log/messages
log_group_name = ${AWS::StackName}-/var/log/messages
log_stream_name = ${AWS::StackName}
datetime_format = %b %d %H:%M:%S

[/mnt/storage/mongodb/logs/mongod.log]
file = /mnt/storage/mongodb/logs/mongod.log
log_group_name = ${AWS::StackName}-/mnt/storage/mongodb/logs/mongod.log
log_stream_name = ${AWS::StackName}
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
