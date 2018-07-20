## How to use `prepare_server_for_mongo.sh`
To use `prepare_server_for_mongo.sh` there are some options we need to pass to the script. Copy the script to some folder on Ubuntu server and make script executable.
Run script as a sudo.

To prepare server for data member you should execute script as follows:

```
$ sudo ./prepare_server_for_mongo.sh -d mongodb1.mydomain.org -a 0
```

To execute script on server that will be eventually arbiter you should execute as:

```
$ sudo ./prepare_server_for_mongo.sh -d mongodb1.mydomain.org -a 1
```

After the script finishes you can check, if everything went ok by executing `sudo mount -a` and by data member we should check, if additional volume that we mounted to the EC2 is really xfs. For that we can use `df -Th /mnt/storage` command.
If everything seems ok, run `sudo reboot`.

## How to use `setup_mongo.sh`
After you finished with `prepare_server_for_mongo.sh` script, copy `setup_mongo.sh` onto server, make it executable. By executing the script you should pass some options as well.

```
$ sudo ./setup_mongo.sh -r myReplica -k 1 -b my-s3-bucket -a 0
```
or

```
$ sudo ./setup_mongo.sh -r myReplica -k 0 -b my-s3-bucket -a 0
```

If we are creating multiple data members, we should pass `-k 1` just one time, since this will generate `keyFile` that will be uploaded to the S3 bucket, that we provided under `-b` option.
When we set `-k 0`, the first time generate `keyFile` will be copied from S3 bucket to the server. Make sure that EC2 instances have sufficient permissions to access S3 bucket.

For arbiter we run as:

```
$ sudo ./setup_mongo.sh -r myReplica -k 0 -b my-s3-bucket -a 1
```

## How to use `setup_logging.sh`
This script will setup log rotation and aws logs. Options `-s` mean stack name and it will be used for log group and stream name. Copy script to Ubuntu server and run on data member as follows:

```
$ sudo ./setup_log.sh -s MyMongoReplicaSetMember1 -a 0
```

for arbiter run as:

```
$ sudo ./setup_log.sh -s MyMongoReplicaSetArbiter -a 1
```

## How to use `setup_cw_metrics.sh`
Before you can run and set CloudWatch metrics your instances should have some policies attached to the role that EC2 instances are using:

* cloudwatch:PutMetricData
* cloudwatch:GetMetricStatistics
* cloudwatch:ListMetrics
* ec2:DescribeTags

Copy script to server, make it executable and run as:

```
$ ./setup_cw_metrics.sh -a 0
```

for arbiter run as:

```
$ ./setup_cw_metrics.sh -a 1
```

For some reason you need to execute `crontab -e` manually, for crontab changes to take effect.
