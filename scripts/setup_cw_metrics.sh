#!/bin/bash -xe

usage() { echo "Usage: $0 -a <0|1> -i <INSTANCE_TYPE>" 1>&2; exit 1; }

while getopts ":a:i:" OPTION; do
    case $OPTION in
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

if [ -z "$ARBITER" ]; then
  echo "-a [option] is required"
  usage
fi

if [ -z "$INSTANCE_TYPE" ]; then
  echo "-i [option] is required"
  usage
fi

if ! grep -q "LANGUAGE" ~/.bash_profile; then
tee ~/.bash_profile <<EOF
PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
alias ls='ls --color=auto'

if [ -z "$LANGUAGE" ] || [ -z "$LANG" ]; then
    export LANGUAGE=de_DE.UTF-8 && export LANG=de_DE.UTF-8 && export LC_ALL=de_DE.UTF-8 && sudo locale-gen de_DE.UTF-8
    sudo dpkg-reconfigure --frontend=noninteractive locales
fi
EOF
source ~/.bash_profile
fi

sudo apt-get install -y unzip libwww-perl libdatetime-perl

curl https://aws-cloudwatch.s3.amazonaws.com/downloads/CloudWatchMonitoringScripts-1.2.2.zip -O

unzip CloudWatchMonitoringScripts-1.2.2.zip && \
rm CloudWatchMonitoringScripts-1.2.2.zip && \
cd aws-scripts-mon

if [ "$ARBITER" = "1" ]; then

sudo tee -a /var/spool/cron/crontabs/ubuntu <<EOF
*/5 * * * * /home/ubuntu/aws-scripts-mon/mon-put-instance-data.pl --mem-used-incl-cache-buff --mem-util --disk-space-util --disk-path=/dev/xvda1 --from-cron
EOF

else

sudo tee -a /var/spool/cron/crontabs/ubuntu <<EOF
*/5 * * * * /home/ubuntu/aws-scripts-mon/mon-put-instance-data.pl --mem-used-incl-cache-buff --mem-util --disk-space-util --disk-path=/dev/xvda1 --from-cron
*/5 * * * * /home/ubuntu/aws-scripts-mon/mon-put-instance-data.pl --mem-used-incl-cache-buff --mem-util --disk-space-util --disk-path=/dev/xvdb1 --from-cron
EOF

fi
