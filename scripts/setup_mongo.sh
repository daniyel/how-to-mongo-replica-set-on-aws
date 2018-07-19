#!/bin/bash -xe

usage() { echo "Usage: $0 [-r <REPLICA_SET_NAME>] [-k <0|1>] [-b <S3_BUCKET>] [-a <0|1>]" 1>&2; exit 1; }

while getopts ":r:k:b:a:" OPTION; do
    case $OPTION in
        r)
            REPLICA_SET_NAME=$OPTARG
            ;;
        k)
            GENERATE_KEY_FILE=$OPTARG
            ((k == 0 || k == 1)) || usage
            ;;
        b)
            S3_BUCKET_NAME=$OPTARG
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

if [ -z "$REPLICA_SET_NAME" ]; then
  echo "-r [option] is required"
  usage
fi

if [ -z "$GENERATE_KEY_FILE" ]; then
  echo "-k [option] is required"
  usage
fi

if [ -z "$S3_BUCKET_NAME" ]; then
  echo "-b [option] is required"
  usage
fi

if [ -z "$ARBITER" ]; then
  echo "-a [option] is required"
  usage
fi

export LANGUAGE=de_DE.UTF-8 && export LANG=de_DE.UTF-8 && export LC_ALL=de_DE.UTF-8 && sudo locale-gen de_DE.UTF-8
sudo dpkg-reconfigure --frontend=noninteractive locales

sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/4.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.0.list
sudo apt-get update
sudo apt-get install -y awscli mongodb-org


if [ "$ARBITER" = "1"]; then

AWS_REGION=$(curl -s 169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//')
aws s3 cp s3://${S3_BUCKET_NAME}/keys/keyFile /opt/mongodb/keyFile --region $AWS_REGION

# Set the ownership and permissions of the keyfile to mongodb
sudo chown mongodb:mongodb /opt/mongodb/keyFile
sudo chmod 0600 /opt/mongodb/keyFile

sudo mkdir -p /var/run/mongod
sudo chown -R mongodb:mongodb /var/run/mongod

sudo tee /etc/mongod.conf <<EOF
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
  timeStampFormat: iso8601-utc

storage:
  dbPath: /var/lib/mongo
  journal:
    enabled: true

processManagement:
  fork: true
  pidFilePath: /var/run/mongod/mongod.pid
  timeZoneInfo: /usr/share/zoneinfo

net:
  port: 27017
  bindIpAll: true

security:
  keyFile: /opt/mongodb/keyFile

replication:
  replSetName: ${REPLICA_SET_NAME}
EOF

sudo tee /etc/systemd/system/mongod.service <<EOF
[Unit]
Description=High-performance, schema-free document-oriented database
After=syslog.target network.target

[Service]
PermissionsStartOnly=true
Type=forking
User=mongodb
Group=mongodb
ExecStart=/usr/bin/mongod --quiet --config /etc/mongod.conf
# file size
LimitFSIZE=infinity
# cpu time
LimitCPU=infinity
# virtual memory size
LimitAS=infinity
# open files
LimitNOFILE=64000
# processes/threads
LimitNPROC=64000
# locked memory
LimitMEMLOCK=infinity
# total threads (user+kernel)
TasksMax=infinity
TasksAccounting=false
# Recommended limits for for mongod as specified in
# http://docs.mongodb.org/manual/reference/ulimit/#recommended-settings

[Install]
WantedBy=multi-user.target
EOF

sudo mkdir -p /var/lib/mongo

sudo chown mongodb:mongodb -R /var/lib/mongo

else

sudo mkdir -p /mnt/storage/mongodb
sudo chown mongodb:mongodb -R /mnt/storage/mongodb

if [ "${GENERATE_KEY_FILE}" -eq "0" ]; then
    AWS_REGION=$(curl -s 169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//')
    aws s3 cp s3://${S3_BUCKET_NAME}/keys/keyFile /mnt/storage/mongodb/keyFile --region $AWS_REGION
else
    AWS_REGION=$(curl -s 169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//')
    sudo openssl rand -base64 741 > keyFile
    sudo cp keyFile /mnt/storage/mongodb
    aws s3 cp /mnt/storage/mongodb/keyFile s3://${S3_BUCKET_NAME}/keys/keyFile --region $AWS_REGION
fi

# Set the ownership and permissions of the keyfile to mongodb
sudo chown mongodb:mongodb /mnt/storage/mongodb/keyFile
sudo chmod 0600 /mnt/storage/mongodb/keyFile

sudo mkdir -p /var/run/mongod
sudo chown -R mongodb:mongodb /var/run/mongod

sudo tee /mnt/storage/mongodb/mongod.conf <<EOF
systemLog:
  destination: file
  logAppend: true
  path: /mnt/storage/mongodb/logs/mongod.log
  timeStampFormat: iso8601-utc

storage:
  dbPath: /mnt/storage/mongodb/data
  directoryPerDB: true
  engine: wiredTiger
  journal:
    enabled: true
  wiredTiger:
    engineConfig:
      journalCompressor: none
      directoryForIndexes: true
    collectionConfig:
      blockCompressor: snappy
    indexConfig:
      prefixCompression: true

processManagement:
  fork: true
  pidFilePath: /mnt/storage/mongodb/mongod.pid
  timeZoneInfo: /usr/share/zoneinfo

net:
  port: 27017
  bindIpAll: true

security:
  keyFile: /mnt/storage/mongodb/keyFile

replication:
  replSetName: ${REPLICA_SET_NAME}
EOF

sudo tee /etc/systemd/system/mongod.service <<EOF
[Unit]
Description=High-performance, schema-free document-oriented database
After=syslog.target network.target

[Service]
PermissionsStartOnly=true
Type=forking
User=mongodb
Group=mongodb
ExecStart=/usr/bin/mongod --quiet --config /mnt/storage/mongodb/mongod.conf
# file size
LimitFSIZE=infinity
# cpu time
LimitCPU=infinity
# virtual memory size
LimitAS=infinity
# open files
LimitNOFILE=64000
# processes/threads
LimitNPROC=64000
# locked memory
LimitMEMLOCK=infinity
# total threads (user+kernel)
TasksMax=infinity
TasksAccounting=false
# Recommended limits for for mongod as specified in
# http://docs.mongodb.org/manual/reference/ulimit/#recommended-settings

[Install]
WantedBy=multi-user.target
EOF

sudo mkdir -p /mnt/storage/mongodb/logs
sudo mkdir -p /mnt/storage/mongodb/data

sudo chown mongodb:mongodb -R /mnt/storage/mongodb

fi

sudo systemctl enable mongod.service
sudo service mongod restart
