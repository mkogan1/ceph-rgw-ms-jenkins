#!/usr/bin/env bash
#set -e
source /opt/rh/gcc-toolset-12/enable

if [[ -z "${SRC_DIR_MS}" ]]; then  SRC_DIR_MS="/mnt/raid0/src/ceph--jenkins-01--MS"  ; fi
echo "  >> env SRC_DIR_MS = ${SRC_DIR_MS}"

echo "  > id = $(id)"
echo "  > pwd = $(pwd)"
echo "  > g++ --version = $(g++ --version)"


BLD_DIR_MS1="${SRC_DIR_MS}1/build"
BLD_DIR_MS2="${SRC_DIR_MS}2/build"
echo "  >> env BLD_DIR_MS1 = ${BLD_DIR_MS1}"
echo "  >> env BLD_DIR_MS2 = ${BLD_DIR_MS2}"
#exit 1



###  ZONE 1  ###
echo "###################################################################################################"
echo "###  ZONE -1-                                                                                   ###"
echo "###################################################################################################"
set -x
cd "${BLD_DIR_MS1}" || exit

export CEPH_DEV=0

pwd
df -h / . 
sudo timeout 8s ./bin/radosgw-admin sync status 2>/dev/null
sudo timeout 8s ./bin/radosgw-admin bucket sync status --bucket=test-100m-1000000000000 2>/dev/null | tail -4
sudo timeout 8s ./bin/rados df 2>/dev/null | grep --line-buffered -v default | colrm 100
sleep 4
sudo timeout 8s ./bin/radosgw-admin bucket stats --bucket=test-100m-1000000000000 --sync-stats 2>/dev/null | grep num_shards
sudo timeout 8s ./bin/radosgw-admin sync error list | grep error_code | sort | uniq -c
ls -b ./out/radosgw*asok | xargs -i sh -c 'echo "F={}" ; sudo timeout 4s ./bin/ceph --admin-daemon {} perf dump 2>/dev/null | jq '\''to_entries[] | select(.key|startswith("data-sync-from"))'\'' | sed -e "/poll_latency/,+4d" | egrep "avgcount|sum|fetch_not_modified" ; sudo ./bin/ceph --admin-daemon {} perf dump 2>/dev/null | jq '\''.rgw.qlen'\'' '
sudo timeout 8s ./bin/ceph status 2>/dev/null

set +x
sudo rm -f  ./out/client.admin.*.log



###  ZONE 2  ###
echo "###################################################################################################"
echo "###  ZONE -2-                                                                                   ###"
echo "###################################################################################################"
set -x
cd "${BLD_DIR_MS2}" || exit

export CEPH_DEV=0

sudo timeout 8s ./bin/radosgw-admin sync status 2>/dev/null
sudo timeout 8s ./bin/radosgw-admin bucket sync status --bucket=test-100m-1000000000000 2>/dev/null | tail -4
sudo timeout 8s ./bin/rados df 2>/dev/null | grep --line-buffered -v default | colrm 100
sleep 4
sudo timeout 8s ./bin/radosgw-admin bucket stats --bucket=test-100m-1000000000000 --sync-stats 2>/dev/null | grep num_shards
sudo timeout 8s ./bin/radosgw-admin sync error list | grep error_code | sort | uniq -c
ls -b ./out/radosgw*asok | xargs -i sh -c 'echo "F={}" ; sudo timeout 4s ./bin/ceph --admin-daemon {} perf dump 2>/dev/null | jq '\''to_entries[] | select(.key|startswith("data-sync-from"))'\'' | sed -e "/poll_latency/,+4d" | egrep "avgcount|sum|fetch_not_modified" ; sudo ./bin/ceph --admin-daemon {} perf dump 2>/dev/null | jq '\''.rgw.qlen'\'' '
sudo timeout 8s ./bin/ceph status 2>/dev/null
set +x
sudo rm -f  ./out/client.admin.*.log

