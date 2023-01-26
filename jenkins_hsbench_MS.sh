#!/usr/bin/env bash
#set -e
echo "  >>>>>> \$0 = ${0}"
source /opt/rh/gcc-toolset-12/enable

if [[ -z "${SRC_DIR_MS}" ]]; then  SRC_DIR_MS="/mnt/raid0/src/ceph--jenkins-01--MS"  ; fi
echo "  >> env SRC_DIR_MS = ${SRC_DIR_MS}"
if [[ -z "${HSBENCH_STAGE}" ]]; then  HSBENCH_STAGE=1  ; fi
echo "  >> env HSBENCH_STAGE = ${HSBENCH_STAGE}"
if [[ -z "${OBJS_PER_STAGE_MS}" ]]; then  OBJS_PER_STAGE_MS=12500000  ; fi
# if [[ -z "${OBJS_PER_STAGE_MS}" ]]; then  OBJS_PER_STAGE_MS=100000  ; fi
echo "  >> env OBJS_PER_STAGE_MS = ${OBJS_PER_STAGE_MS}"


echo "  > id = $(id)"
echo "  > pwd = $(pwd)"
echo "  > g++ --version = $(g++ --version)"


BLD_DIR_MS1="${SRC_DIR_MS}1/build"
BLD_DIR_MS2="${SRC_DIR_MS}2/build"
echo "  >> env BLD_DIR_MS1 = ${BLD_DIR_MS1}"
echo "  >> env BLD_DIR_MS2 = ${BLD_DIR_MS2}"
#exit 1
#exit 0


ulimit -a ; ulimit -n 262144 ; ulimit -a


# if false; then
if true; then
  echo "> restarting OSDs to prevent OOM:"
  sudo pkill ceph-osd
  while [[ $(pgrep -a ceph-osd | wc -l) -gt 0 ]]; do 
    echo "." ; sleep 4
  done
  export TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES=134217728
  export TCMALLOC_RELEASE_RATE=1
  
  ###  ZONE 1  ###
  echo "###################################################################################################"
  echo "###  ZONE -1-                                                                                   ###"
  echo "###################################################################################################"
  set -x
  cd "${BLD_DIR_MS1}" || exit
  pwd
  sudo numactl -N 0 -m 0 -- env TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES=${TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES} TCMALLOC_RELEASE_RATE=${TCMALLOC_RELEASE_RATE}  /usr/local/bin/eatmydata ./bin/ceph-osd -i 0 -c ./ceph.conf --bluestore_fsck_quick_fix_on_mount=true --bluestore_fsck_on_mount=false --bluestore_fsck_on_mount_deep=false
  sleep 10

  sudo rm -v ./hsbench.log
  nice numactl -N 0 -m 0 -- ~/go/bin/hsbench -a b2345678901234567890 -s b234567890123456789012345678901234567890 -u http://127.0.0.1:8000 -z 4K -d -1 -t  400 -b 1 -n ${OBJS_PER_STAGE_MS} -m ip -bp test-100m-1 -op useast_stage${HSBENCH_STAGE}_ &> ./hsbench.log &
  sleep 5
  
  set +x
  

  ###  ZONE 2  ###
  echo "###################################################################################################"
  echo "###  ZONE -2-                                                                                   ###"
  echo "###################################################################################################"
  set -x
  cd "${BLD_DIR_MS2}" || exit
  pwd
  sudo numactl -N 1 -m 1 -- env TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES=${TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES} TCMALLOC_RELEASE_RATE=${TCMALLOC_RELEASE_RATE}  /usr/local/bin/eatmydata ./bin/ceph-osd -i 0 -c ./ceph.conf --bluestore_fsck_quick_fix_on_mount=true --bluestore_fsck_on_mount=false --bluestore_fsck_on_mount_deep=false
  sleep 10

  sudo rm -v ./hsbench.log
  nice numactl -N 1 -m 1 -- ~/go/bin/hsbench -a b2345678901234567890 -s b234567890123456789012345678901234567890 -u http://127.0.0.1:8004 -z 4K -d -1 -t  400 -b 1 -n ${OBJS_PER_STAGE_MS} -m ip -bp test-100m-1 -op uswest_stage${HSBENCH_STAGE}_ &> ./hsbench.log &

  set +x
fi



echo "###################################################################################################"
echo "###  Wait For Completion                                                                        ###"
echo "###################################################################################################"
while sleep 10; do
  date


  echo "###  ZONE -1-                                                                                   ###"
  set -x
  cd "${BLD_DIR_MS1}" || exit
  pwd
  OBJS_MS1=$(sudo timeout 8s ./bin/rados df 2>/dev/null | grep --line-buffered -v default | grep "buckets.data" | awk '{ print $4 }')
  SYNC_CAUGHT_UP_MS1=$(sudo timeout 8s ./bin/radosgw-admin sync status 2>/dev/null | grep -c 'data is caught up')
  BUCKET_CAUGHT_UP_MS1=$(sudo timeout 8s ./bin/radosgw-admin bucket sync status --bucket=test-100m-1000000000000 2>/dev/null | grep -c 'bucket is caught up')
  set +x


  echo "###  ZONE -2-                                                                                   ###"
  set -x
  cd "${BLD_DIR_MS2}" || exit
  pwd
  OBJS_MS2=$(sudo timeout 8s ./bin/rados df 2>/dev/null | grep --line-buffered -v default | grep "buckets.data" | awk '{ print $4 }')
  SYNC_CAUGHT_UP_MS2=$(sudo timeout 8s ./bin/radosgw-admin sync status 2>/dev/null | grep -c 'data is caught up')
  BUCKET_CAUGHT_UP_MS2=$(sudo timeout 8s ./bin/radosgw-admin bucket sync status --bucket=test-100m-1000000000000 2>/dev/null | grep -c 'bucket is caught up')
  set +x



  # SYNC completion check
  echo "--[ sync completion success condition check ] -----------------------------------------------------"
  echo " >> OBJS_MS1 = $(numfmt --g ${OBJS_MS1})  <|--  HSBENCH_STAGE=${HSBENCH_STAGE} = $(numfmt --g $((OBJS_PER_STAGE_MS * HSBENCH_STAGE * 2))) obj  --|>  OBJS_MS2 = $(numfmt --g ${OBJS_MS2})"
  set -x
  if [[ ${OBJS_MS1} -gt $(( (OBJS_PER_STAGE_MS * HSBENCH_STAGE * 2) - 1000 )) && ${OBJS_MS2} -gt $(( (OBJS_PER_STAGE_MS * HSBENCH_STAGE * 2) - 1000 ))  &&  ${OBJS_MS1} -eq ${OBJS_MS2} ]]; then
    set +x
    echo ">>> OBJECT SYNC complete OK - objects number is CORRECT and both zones MATCH !" ; 
    echo "---------------------------------------------------------------------------------------------------"
    echo " >> SYNC_CAUGHT_UP_MS1 = ${SYNC_CAUGHT_UP_MS1} <|---|> SYNC_CAUGHT_UP_MS2 = ${SYNC_CAUGHT_UP_MS2}  ,  BUCKET_CAUGHT_UP_MS1 = ${BUCKET_CAUGHT_UP_MS1} <|---|> BUCKET_CAUGHT_UP_MS2 = ${BUCKET_CAUGHT_UP_MS2}"
    set -x
    if [[ ${SYNC_CAUGHT_UP_MS1} -eq 1  &&  ${SYNC_CAUGHT_UP_MS2} -eq 2  &&  ${BUCKET_CAUGHT_UP_MS1} -eq 1  && ${BUCKET_CAUGHT_UP_MS2} -eq 1 ]]; then
      set +x ; echo ">>> SYNC and BUCKET SYNC complete SUCCESSFULLY - both zones are CAUGHT UP and Object number is SAME !" ; set -x
      exit 0
    fi
  fi
  set +x
  sudo rm -f  ./out/client.admin.*.log
  sudo find /var/tmp/ -type f -name "scl*" -delete
  echo "==[ sleep loop ... ]==============================================================================="

done
