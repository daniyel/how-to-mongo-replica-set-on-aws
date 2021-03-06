# How to for Mongo DB (v4.0.0) replica set on AWS
How to for mongo replica set on AWS. This how to will use Ubuntu 16.04 LTS and `m4.large` or `m5.large` for data member and `t2.micro` for arbiter. You can deploy as many data member as you like and you can attach any size as additional volume (in our case we will be using 100 GB as additional volume). Root volume will stay at standard 8 GB, since in Mongo Db preferences we will map everything to the second volume.


## Monitoring Memory and Disk Metrics for Amazon EC2 Linux Instances
https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/mon-scripts.html

## Creating special user for database

Login to the primary data member of replica set and execute following command (replace values that start with `my` prefix).

```
myReplicaSet:PRIMARY> use admin
myReplicaSet:PRIMARY> db.createUser({user: "myUser", pwd: "myPassword", roles: [{role: "readWrite", db: "myDatabase"}, {role:"dbAdmin", db: "myDatabase"}]})
```
