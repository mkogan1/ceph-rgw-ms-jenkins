# MS Jenkins installation:

## Pre-requisites installation:
- s3cmd -- 
`sudo dnf install s3cmd`
s3cfg : https://github.com/mkogan1/ceph-rgw-ms-jenkins/blob/main/s3cfg

- hsbench -- install after jenkins is installed:
```
sudo -i su - jenkins -s /bin/bash
go install -v github.com/markhpc/hsbench@latest
logout
```

- install eatmydata
```
git clone https://github.com/stewartsmith/libeatmydata.git
cd libeatmydata
sudo dnf install -y strace
autoreconf -i
./configure
make -j
make check
sudo make install
```


## Jenkins installation
refrences:
- https://www.jenkins.io/doc/ -- Jenkins User Documentation
- https://www.jenkins.io/doc/book/installing/linux/#red-hat-centos -- Installing Jenkins
- https://www.howtoforge.com/tutorial/ubuntu-jenkins-automation-server/ -- How to Install Jenkins on Ubuntu 22.04
- https://www.tecmint.com/install-jenkins-on-centos-8/ -- How to Install Jenkins on CentOS 8
- https://www.digitalocean.com/community/tutorials/how-to-set-up-jenkins-for-continuous-development-integration-on-centos-7 -- How To Set Up Jenkins for Continuous Development Integration on CentOS 7

- https://stackoverflow.com/questions/11880070/how-to-run-a-script-as-root-in-jenkins -- How to run a script as root in Jenkins?



```
cat /etc/redhat-release
Red Hat Enterprise Linux release 8.7 (Ootpa)

sudo dnf install java-11-openjdk

rpm -qa | grep java
javapackages-filesystem-5.3.0-2.module+el8+2598+06babf2e.noarch
java-11-openjdk-11.0.17.0.8-2.el8_6.x86_64
javapackages-tools-5.3.0-2.module+el8+2598+06babf2e.noarch
java-11-openjdk-headless-11.0.17.0.8-2.el8_6.x86_64
tzdata-java-2022g-1.el8.noarch
java-1.8.0-openjdk-1.8.0.352.b08-2.el8_7.x86_64
java-1.8.0-openjdk-headless-1.8.0.352.b08-2.el8_7.x86_64
java-1.8.0-openjdk-devel-1.8.0.352.b08-2.el8_7.x86_64

sudo dnf remove java-1.8.0-openjdk java-1.8.0-openjdk-headless java-1.8.0-openjdk-devel


sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo 
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
sudo dnf upgrade
sudo dnf install jenkins
sudo systemctl daemon-reload


sudo systemctl enable jenkins --now
sudo systemctl status jenkins
Jan 08 18:32:08 folio09 jenkins[2613353]: Jenkins initial setup is required. An admin user has been created and a password generated.
Jan 08 18:32:08 folio09 jenkins[2613353]: Please use the following password to proceed to installation:
Jan 08 18:32:08 folio09 jenkins[2613353]: d140f2639b204d73b11a0b5c637b8e16
Jan 08 18:32:08 folio09 jenkins[2613353]: This may also be found at: /var/lib/jenkins/secrets/initialAdminPassword
Jan 08 18:32:08 folio09 jenkins[2613353]: *************************************************************


sudo journalctl -f -u jenkins.service
sudo journalctl --since "1 hour ago"


firewall-cmd --permanent --new-service=jenkins
firewall-cmd --permanent --service=jenkins --set-short="Jenkins ports"
firewall-cmd --permanent --service=jenkins --set-description="Jenkins port exceptions"
firewall-cmd --permanent --service=jenkins --add-port=8080/tcp
firewall-cmd --permanent --service=jenkins --add-service=jenkins
firewall-cmd --zone=public --add-service=http --permanent
firewall-cmd --reload


sudo visudo
…
## Allows members of the 'sys' group to run networking, software,
## service management apps and more.
# %sys ALL = NETWORKING, SOFTWARE, SERVICES, STORAGE, DELEGATING, PROCESSES, LOCATE, DRIVERS

## Allows people in group wheel to run all commands
# %wheel        ALL=(ALL)       ALL

## Same thing without a password
%wheel  ALL=(ALL)       NOPASSWD: ALL
jenkins ALL=(ALL)       NOPASSWD: ALL
…

sudo usermod -a -G wheel jenkins
sudo usermod -a -G sudo jenkins


firefox http://folio09.front.sepia.ceph.com:8080
```

## Terminal access to sync status and logs:
```
cd /mnt/raid0/src/ceph--jenkins-01--MS1/build
# - or -
cd /mnt/raid0/src/ceph--jenkins-01--MS2/build

cd $PWD ; nice watch -cd "cd $PWD ; df -h / . | ccze -Aonolookups ; sudo timeout 4s ./bin/radosgw-admin sync status 2>/dev/null | ccze -Aonolookups ; sudo timeout 4s ./bin/radosgw-admin bucket sync status --bucket=test-100m-1000000000000 2>/dev/null | colrm 142 | tail -4 | ccze -Aonolookups ; sudo timeout 4s ./bin/rados df 2>/dev/null | grep -v default | colrm 142 | ccze -Aonolookups ; sudo timeout 4s ./bin/radosgw-admin bucket stats --bucket=test-100m-1000000000000 --sync-stats 2>/dev/null | grep num_shards ; sudo timeout 4s ./bin/radosgw-admin sync error list | grep error_code | sort | uniq -c ; ls -b ./out/radosgw*asok | xargs -i sh -c 'echo \"F={}\" ; sudo timeout 4s ./bin/ceph --admin-daemon {} perf dump 2>/dev/null | jq -C '\''to_entries[] | select(.key|startswith(\"data-sync-from\"))'\'' | sed -e \"/poll_latency/,+4d\" | egrep \"avgcount|sum|fetch_not_modified\" ; sudo ./bin/ceph --admin-daemon {} perf dump 2>/dev/null | jq -C '\''.rgw.qlen'\'' ' ; sudo timeout 4s ./bin/ceph status 2>/dev/null | ccze -Aonolookups ; sudo rm -f  ./out/client.admin.*.log"
```

