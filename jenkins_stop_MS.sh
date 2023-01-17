#!/usr/bin/env bash
#set -e
echo "  >>>>>> \$0 = ${0}"
source /opt/rh/gcc-toolset-12/enable

if [[ -z "${SRC_DIR_MS}" ]]; then  SRC_DIR_MS="/mnt/raid0/src/ceph--jenkins-01--MS"  ; fi
echo "  >> env SRC_DIR_MS = ${SRC_DIR_MS}"

echo "  > id = $(id)"
echo "  > pwd = $(pwd)"
echo "  > g++ --version = $(g++ --version)"


BLD_DIR_MS1="${SRC_DIR_MS}1/build"
echo "  >> env BLD_DIR_MS1 = ${BLD_DIR_MS1}"


set -x
cd "${BLD_DIR_MS1}" || exit


pgrep -a ceph- ; pgrep -a rados | grep -v radosgw-admin ; pgrep -a haproxy
sudo ../src/stop.sh ; sudo pkill -9 radosgw ; sudo pkill -9 haproxy ; sudo pkill -9 ceph-osd ; pkill -9 s3cmd ; sudo pkill -9 hsbench
pgrep -a ceph- ; pgrep -a rados | grep -v radosgw-admin ; pgrep -a haproxy

exit 0
