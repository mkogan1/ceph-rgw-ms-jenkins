#!/usr/bin/env bash
#set -e
echo "  >>>>>> \$0 = ${0}"
source /opt/rh/gcc-toolset-12/enable

if [[ -z "${SRC_DIR_MS}" ]]; then  SRC_DIR_MS="/mnt/raid0/src/ceph--jenkins-01--MS"  ; fi
echo "  >> env SRC_DIR_MS = ${SRC_DIR_MS}"
if [[ -z "${VSTART_CONF_PARAMS_MS}" ]]; then  VSTART_CONF_PARAMS_MS="-o rgw_max_objs_per_shard=100000 -o rgw_max_dynamic_shards=1999 -o rgw_data_notify_interval_msec=0 -o rgw_curl_low_speed_time=30 -o rgw_sync_log_trim_interval=1200 -o rgw_md_log_max_shards=64 -o rgw_data_log_num_shards=128 -o rgw_default_data_log_backing=fifo -o rgw_data_log_window=30 -o rgw_bucket_index_transaction_instrumentation=false -o rgw_sync_lease_period=1200"  ; fi
echo "  >> env VSTART_CONF_PARAMS_MS = ${VSTART_CONF_PARAMS_MS}"
if [[ -z "${S3CFG_PATH_MS}" ]]; then  SRC_DIR_MS="/mnt/raid0/src/ceph-rgw-ms-jenkins/s3cfg"  ; fi
echo "  >> env S3CFG_PATH_MS = ${S3CFG_PATH_MS}"

if [[ -z "${DEBUG_RGW_SYNC}" ]]; then  DEBUG_RGW_SYNC="20"  ; fi
echo "  >> env DEBUG_RGW_SYNC = ${DEBUG_RGW_SYNC}"
if [[ -z "${DEBUG_OBJCLASS}" ]]; then  DEBUG_OBJCLASS="20"  ; fi
echo "  >> env DEBUG_OBJCLASS = ${DEBUG_OBJCLASS}"
if [[ -z "${DEBUG_RGW}" ]]; then  DEBUG_RGW="1"  ; fi
echo "  >> env DEBUG_RGW = ${DEBUG_RGW}"
if [[ -z "${DEBUG_MS}" ]]; then  DEBUG_MS="0"  ; fi
echo "  >> env DEBUG_MS = ${DEBUG_MS}"


echo "  > id = $(id)"
echo "  > pwd = $(pwd)"
echo "  > g++ --version = $(g++ --version)"


BLD_DIR_MS1="${SRC_DIR_MS}1/build"
BLD_DIR_MS2="${SRC_DIR_MS}2/build"
echo "  >> env BLD_DIR_MS1 = ${BLD_DIR_MS1}"
echo "  >> env BLD_DIR_MS2 = ${BLD_DIR_MS2}"
#exit 1

set -x
sudo modprobe -vr zram ; sudo rm -vf /dev/zram0 /dev/zram1 /dev/zram2 /dev/zram3 ; sudo modprobe -v zram num_devices=4
sudo zramctl /dev/zram0 -t 4 -s 33GB -a lzo; sudo zramctl /dev/zram1 -t 4 -s 6GB -a lzo
sudo zramctl /dev/zram2 -t 4 -s 33GB -a lzo; sudo zramctl /dev/zram3 -t 4 -s 6GB -a lzo
sudo zramctl
set +x

###  ZONE 1  ###
echo "###################################################################################################"
echo "###  ZONE -1-                                                                                   ###"
echo "###################################################################################################"
set -x
cd "${BLD_DIR_MS1}" || exit


pgrep -a ceph- ; pgrep -a rados | grep -v radosgw-admin ; pgrep -a haproxy
sudo ../src/stop.sh ; sudo pkill -9 radosgw ; sudo pkill -9 ceph-osd ; pkill -9 s3cmd
pgrep -a ceph- ; pgrep -a rados | grep -v radosgw-admin ; pgrep -a haproxy

ulimit -n 262144 ; ulimit -a
export TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES=134217728
export TCMALLOC_AGGRESSIVE_DECOMMIT=false 
export TCMALLOC_RELEASE_RATE=1
export CEPH_DEV=0

sudo find ./out -maxdepth 1 -type f -delete ; sudo find ./out -maxdepth 1 -type s -delete ; sudo rm -rfv ./out* ; sudo rm -rf ./dev/* ; sudo chown $(id -nu):$(id -ng) -R *
sudo wipefs -a /dev/zram0 ; sudo wipefs -a /dev/zram1 ; sudo wipefs -a /dev/zram2 ; sudo wipefs -a /dev/zram3
sudo sysctl kernel.randomize_va_space=0 ; sudo sysctl vm.compact_memory=1 #; sync #; sudo sysctl vm.drop_caches=3

sudo numactl -N 0 -m 0 -- env GLIBC_TUNABLES="glibc.elision.enable=${GEE}"  MON=1 OSD=1 MDS=0 MGR=1 RGW=1 NFS=0  ../src/vstart.sh \
-n -X -o ms_mon_client_mode=crc -o mon_data_avail_crit=0 \
--bluestore --nolockdep --without-dashboard -o debug_ms=0 -o debug_objecter=0 -o bluestore_debug_enforce_settings=ssd -o bluestore_block_size=$((2500 * 1024*1024*1024)) \
-o bluestore_block_db_path=/dev/zram0 -o bluestore_block_db_create=true -o bluestore_block_wal_path=/dev/zram1 -o bluestore_block_wal_create=true \
-o mon_enable_op_tracker=false -o osd_enable_op_tracker=false -o rgw_override_bucket_index_max_shards=0 -o rgw_dynamic_resharding=0 -o rgw_reshard_thread_interval=600 \
-o rgw_resharding_multiplier_multisite=4 -o rgw_bucket_index_max_aio=256 -o rgw_put_obj_max_window_size=134217728 \
-o bluestore_csum_type=none -o rocksdb_cache_size=1073741824 -o rgw_cache_lru_size=1000000 \
-o rgw_get_obj_max_req_size=25165824 -o rgw_get_obj_window_size=25165824 -o rgw_max_chunk_size=25165824 -o rgw_max_listing_results=2000  -o osd_pool_default_pg_num=128 \
-o osd_pool_default_pgp_num=128 -o mon_pg_warn_max_per_osd=10000 -o mon_max_pg_per_osd=9999 -o osd_pool_default_pg_autoscale_mode=warn  -o osd_journal_size=10240 -o osd_max_write_size=512 \
-o osd_map_cache_size=1024 -o osd_op_log_threshold=50  -o bluestore_min_alloc_size=4096 -o bluestore_min_alloc_size_hdd=4096 \
-o bluestore_min_alloc_size_ssd=4096  -o ms_dispatch_throttle_bytes=1048576000 -o ms_crc_data=false -o ms_crc_header=false -o ms_async_op_threads=6 -o ms_async_max_op_threads=16 \
-o objecter_inflight_op_bytes=5368709120 -o objecter_inflight_ops=24576 -o osd_op_num_threads_per_shard=2 -o bluestore_cache_trim_max_skip_pinned=10000   -o osd_pg_log_dups_tracked=10 \
-o osd_pg_log_trim_min=10 -o max_open_files=500000 -o mon_allow_pool_delete=true -o mon_allow_pool_size_one=true -o mutex_perf_counter=false -o throttler_perf_counter=false \
-o bluestore_volume_selection_policy=use_some_extra -o bluestore_default_buffered_read=true -o bluestore_default_buffered_write=false -o bluefs_buffered_io=true \
-o osd_mclock_force_run_benchmark_on_init=1 -o bluestore_allocation_from_file=true -o bluestore_default_buffered_read=true -o bluestore_default_buffered_write=false \
-o bluefs_buffered_io=true -o bluestore_fsck_quick_fix_on_mount=true -o bluestore_fsck_on_mount=false -o bluestore_fsck_on_mount_deep=false \
--rgw_frontend "beast tcp_nodelay=1 request_timeout_ms=0" -o rgw_curl_tcp_keepalive=1  ${VSTART_CONF_PARAMS_MS}  \
-o rgw_list_buckets_max_chunk=999999 -o bluestore_cache_autotune=false -o bluestore_cache_meta_ratio=0.8 -o bluestore_cache_kv_ratio=0.2  -o osd_memory_target_autotune=true \
-o osd_memory_target=8589934592 -o osd_memory_cache_min=4294967296 -o bluestore_cache_size=4294967296 -o bluestore_throttle_bytes=53687091200 \
-o bluestore_throttle_deferred_bytes=107374182400

# BISECT - lower memory usage:
#-o osd_pg_object_context_cache_count=10240
#-o osd_min_pg_log_entries=30000 -o osd_max_pg_log_entries=100000 

sudo ./bin/radosgw-admin user create --display-name="cosbench_user" --uid=cosbench --access-key b2345678901234567890 --secret b234567890123456789012345678901234567890
sudo ./bin/radosgw-admin subuser create --uid=cosbench --subuser=cosbench:operator --secret=redhat --access=full --key-type=swift
sudo ./bin/radosgw-admin user modify --uid=cosbench --max-buckets=0

sudo pgrep -a ceph-osd ; sudo pkill -9 ceph-osd ; sleep 1.6
sudo numactl -N 0 -m 0 -- env TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES=${TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES} TCMALLOC_RELEASE_RATE=${TCMALLOC_RELEASE_RATE} GLIBC_TUNABLES="glibc.elision.enable=${GEE}"  /usr/local/bin/eatmydata ./bin/ceph-osd -i 0 -c ./ceph.conf ; sleep 1.5
numactl --hardware
sudo ./bin/ceph osd set noscrub ; sudo ./bin/ceph osd set nodeep-scrub

sudo pgrep -a radosgw ; sudo pkill -9 radosgw ; sleep 0.4 ; sudo truncate -s0 ./out/radosgw.8000.log
sudo numactl -N 0 -m 0 -- env TCMALLOC_LARGE_ALLOC_REPORT_THRESHOLD=268435456 TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES=${TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES} TCMALLOC_AGGRESSIVE_DECOMMIT=${TCMALLOC_AGGRESSIVE_DECOMMIT}  TCMALLOC_RELEASE_RATE=${TCMALLOC_RELEASE_RATE}  /usr/local/bin/eatmydata ./bin/radosgw  --nolockdep -c ./ceph.conf --log-file=./out/radosgw.8000.log --admin-socket=./out/radosgw.8000.asok --pid-file=./out/radosgw.8000.pid -n client.rgw.8000 --rgw_frontends="beast port=8000 tcp_nodelay=1 request_timeout_ms=0"  # -f --default-log-to-file=true --default-log-to-stderr=false

sh -c "sleep 2 ; s3cmd -c ${S3CFG_PATH_MS} mb s3://bkt ; s3cmd -c ${S3CFG_PATH_MS} put ./ceph.conf s3://bkt" &
timeout 35s  tail -F ./out/radosgw.8000.log ; s3cmd -c ${S3CFG_PATH_MS} rm s3://bkt/ceph.conf ; egrep "osd_mclock_max_capacity|bench" ./out/osd.0.log
pgrep -a ceph ; pgrep -a rados

sudo pgrep -a haproxy ; sudo pkill haproxy
tee ./haproxy.cfg << EOF
global
  log stdout  format raw  local0  info
  #log stdout  local0  debug
  spread-checks 3
defaults
  #maxconn 3000
  log global
  option httplog
  mode http
  option dontlognull
  mode http
    option forwardfor   	except 127.0.0.0/8
    timeout queue 100
    ##no option http-keep-alive
    ##option httpclose
    option http-keep-alive
    option http-server-close
	timeout client-fin 1s
	timeout server-fin 1s
    timeout client 		 30s
    timeout server 		 30s
    timeout http-request    10s
    timeout connect		 10s  # TODO: 5s & 20s
    timeout check  		 10s  # TODO: 5s & 20s
    timeout http-keep-alive 10s
frontend stats
	bind *:8404
	stats enable
	stats uri /stats
	stats refresh 10s
	stats admin if TRUE
	maxconn 256
frontend http_S3
  maxconn 6000
  bind *:8100
  option forwardfor
  default_backend rgw
backend rgw
  fullconn 6000
  option redispatch 1
  retry-on all-retryable-errors
  retries 2
  #max-keep-alive-queue 1
  option httpchk
  http-check send meth GET uri /swift/healthcheck
  balance roundrobin
  default-server check maxconn 2000 observe layer7  #error-limit 1  on-error mark-down  inter 1s downinter 5s rise 3 fall 2 maxqueue 1
  server  rgw8001 127.0.0.1:8001
  server  rgw8002 127.0.0.1:8002
  server  rgw8003 127.0.0.1:8003
EOF
#sudo numactl -N 0 -m 0 -- haproxy -f ./haproxy.cfg -D #-d
sudo numactl -N 0 -m 0 -- /usr/local/sbin/haproxy -f ./haproxy.cfg &> haproxy.log &


sudo ./bin/radosgw-admin realm create --rgw-realm=gold --default

sudo ./bin/radosgw-admin zonegroup create --rgw-zonegroup=us --endpoints=http://127.0.0.1:8100 --master --default
sudo ./bin/radosgw-admin zonegroup create --rgw-zonegroup=us --endpoints=http://127.0.0.1:8001,http://127.0.0.1:8002,http://127.0.0.1:8003 --master --default
sudo ./bin/radosgw-admin zone create --rgw-zonegroup=us --rgw-zone=us-east --endpoints=http://127.0.0.1:8100 --access-key m2345678901234567890 --secret m234567890123456789012345678901234567890 --master --default
sudo ./bin/radosgw-admin user create --uid=realm.admin --display-name=RealmAdmin --access-key m2345678901234567890 --secret m234567890123456789012345678901234567890 --system
sudo ./bin/radosgw-admin period update --commit


pgrep -a rados
sudo /usr/bin/kill --verbose -9 $(ps -ef | grep 'bin\/radosgw' | grep "800[0123]" | awk '{ print $2 }')
sleep 2
# hsbench client RGW
sudo numactl -N 0 -m 0 -- env TCMALLOC_LARGE_ALLOC_REPORT_THRESHOLD=268435456 TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES=${TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES} TCMALLOC_AGGRESSIVE_DECOMMIT=${TCMALLOC_AGGRESSIVE_DECOMMIT}  TCMALLOC_RELEASE_RATE=${TCMALLOC_RELEASE_RATE} GLIBC_TUNABLES="glibc.elision.enable=${GEE}"  /usr/local/bin/eatmydata ./bin/radosgw  --nolockdep -c ./ceph.conf --log-file=./out/radosgw.8000.log --admin-socket=./out/radosgw.8000.asok --pid-file=./out/radosgw.8000.pid -n client.rgw.8000 --rgw_frontends="beast port=8000 tcp_nodelay=1 request_timeout_ms=0" --rgw_dynamic_resharding=1 --rgw_run_sync_thread=0 # -f --default-log-to-file=true --default-log-to-stderr=false
# sync RGW
sudo numactl -N 0 -m 0 -- env TCMALLOC_LARGE_ALLOC_REPORT_THRESHOLD=268435456 TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES=${TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES} TCMALLOC_AGGRESSIVE_DECOMMIT=${TCMALLOC_AGGRESSIVE_DECOMMIT}  TCMALLOC_RELEASE_RATE=${TCMALLOC_RELEASE_RATE} GLIBC_TUNABLES="glibc.elision.enable=${GEE}"  /usr/local/bin/eatmydata ./bin/radosgw  --nolockdep -c ./ceph.conf --log-file=./out/radosgw.8001.log --admin-socket=./out/radosgw.8001.asok --pid-file=./out/radosgw.8001.pid -n client.rgw.8001 --rgw_frontends="beast port=8001 tcp_nodelay=1 request_timeout_ms=0" --rgw_dynamic_resharding=1 --rgw_run_sync_thread=1 --rgw_bucket_index_transaction_instrumentation=false --rgw_cache_enabled=true # -f
# sync RGW
sudo numactl -N 0 -m 0 -- env TCMALLOC_LARGE_ALLOC_REPORT_THRESHOLD=268435456 TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES=${TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES} TCMALLOC_AGGRESSIVE_DECOMMIT=${TCMALLOC_AGGRESSIVE_DECOMMIT}  TCMALLOC_RELEASE_RATE=${TCMALLOC_RELEASE_RATE} GLIBC_TUNABLES="glibc.elision.enable=${GEE}"  /usr/local/bin/eatmydata ./bin/radosgw  --nolockdep -c ./ceph.conf --log-file=./out/radosgw.8002.log --admin-socket=./out/radosgw.8002.asok --pid-file=./out/radosgw.8002.pid -n client.rgw.8002 --rgw_frontends="beast port=8002 tcp_nodelay=1 request_timeout_ms=0" --rgw_dynamic_resharding=1 --rgw_run_sync_thread=1 --rgw_bucket_index_transaction_instrumentation=false --rgw_cache_enabled=true # -f
# sync RGW
sudo numactl -N 0 -m 0 -- env TCMALLOC_LARGE_ALLOC_REPORT_THRESHOLD=268435456 TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES=${TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES} TCMALLOC_AGGRESSIVE_DECOMMIT=${TCMALLOC_AGGRESSIVE_DECOMMIT}  TCMALLOC_RELEASE_RATE=${TCMALLOC_RELEASE_RATE} GLIBC_TUNABLES="glibc.elision.enable=${GEE}"  /usr/local/bin/eatmydata ./bin/radosgw  --nolockdep -c ./ceph.conf --log-file=./out/radosgw.8003.log --admin-socket=./out/radosgw.8003.asok --pid-file=./out/radosgw.8003.pid -n client.rgw.8003 --rgw_frontends="beast port=8003 tcp_nodelay=1 request_timeout_ms=0" --rgw_dynamic_resharding=1 --rgw_run_sync_thread=1 --rgw_bucket_index_transaction_instrumentation=false --rgw_cache_enabled=true # -f

pgrep -a rados

sudo ./bin/radosgw-admin user create --display-name="cosbench_user" --uid=cosbench --access-key b2345678901234567890 --secret b234567890123456789012345678901234567890
sudo ./bin/radosgw-admin subuser create --uid=cosbench --subuser=cosbench:operator --secret=redhat --access=full --key-type=swift
sudo ./bin/radosgw-admin user modify --uid=cosbench --max-buckets=0

s3cmd -c ${S3CFG_PATH_MS} --host=127.0.0.1:8000 ls

s3cmd -c ${S3CFG_PATH_MS} mb s3://b01b000000000000 ; s3cmd -c ${S3CFG_PATH_MS} put ./ceph.conf s3://b01b000000000000

pgrep -a ceph ; pgrep -a haproxy ; pgrep -a rados

ls -b1tr ./out/radosgw*.asok | xargs -i echo {}
ls -b1tr ./out/radosgw*.asok | xargs -i sudo ./bin/ceph --admin-daemon {} config show | egrep "rgw_run_sync_thread|rgw_data_log_num_shards|rgw_md_log_max_shards|rgw_data_notify_interval_msec|rgw_default_data_log_backing|rgw_sync_lease_period|rgw_dynamic_resharding|rgw_reshard_thread_interval|rgw_max_objs_per_shard|rgw_sync_log_trim_interval|rgw_bucket_index_transaction_instrumentation|rgw_data_log_window|rgw_curl_low_speed_time|rgw_cache_enabled|rgw_override_bucket_index_max_shards|rgw_thread_pool_size|rgw_max_concurrent_requests|rgw_max_dynamic_shards|rgw_resharding_multiplier_multisite"


ls -b1tr ./out/radosgw*.asok | xargs -i  sudo ./bin/ceph --admin-daemon {} config set debug_ms "${DEBUG_MS}"
ls -b1tr ./out/radosgw*.asok | xargs -i  sudo ./bin/ceph --admin-daemon {} config set debug_rgw "${DEBUG_RGW}"
ls -b1tr ./out/radosgw*.asok | xargs -i  sudo ./bin/ceph --admin-daemon {} config set debug_rgw_sync "${DEBUG_RGW_SYNC}"

ls -b1tr ./out/radosgw*.asok | xargs -i  sudo ./bin/ceph --admin-daemon {} config set debug_objclass "${DEBUG_OBJCLASS}"
sudo ./bin/ceph tell "osd.*" injectargs --debug_objclass "${DEBUG_OBJCLASS}" #; sudo truncate -s0 ./out/osd.0.log

set +x



###  ZONE 2  ###
echo "###################################################################################################"
echo "###  ZONE -2-                                                                                   ###"
echo "###################################################################################################"
set -x
cd "${BLD_DIR_MS2}" || exit


ulimit -n 262144 ; ulimit -a
export TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES=134217728
export TCMALLOC_AGGRESSIVE_DECOMMIT=false 
export TCMALLOC_RELEASE_RATE=1
export CEPH_DEV=0

sudo find ./out -maxdepth 1 -type f -delete ; sudo find ./out -maxdepth 1 -type s -delete ; sudo rm -rfv ./out* ; sudo rm -rf ./dev/* ; sudo chown $(id -nu):$(id -ng) -R *
sudo sysctl kernel.randomize_va_space=0 ; sudo sysctl vm.compact_memory=1 #; sync #; sudo sysctl vm.drop_caches=3

sudo numactl -N 1 -m 1 -- env GLIBC_TUNABLES="glibc.elision.enable=${GEE}"  MON=1 OSD=1 MDS=0 MGR=1 RGW=1 NFS=0  ../src/vstart.sh \
-n -X -o ms_mon_client_mode=crc -o mon_data_avail_crit=0 \
--bluestore --nolockdep --without-dashboard -o debug_ms=0 -o debug_objecter=0 -o bluestore_debug_enforce_settings=ssd -o bluestore_block_size=$((2500 * 1024*1024*1024)) \
-o bluestore_block_db_path=/dev/zram2 -o bluestore_block_db_create=true -o bluestore_block_wal_path=/dev/zram3 -o bluestore_block_wal_create=true \
-o mon_enable_op_tracker=false -o osd_enable_op_tracker=false -o rgw_override_bucket_index_max_shards=0 -o rgw_dynamic_resharding=0 -o rgw_reshard_thread_interval=600 \
-o rgw_resharding_multiplier_multisite=4 -o rgw_bucket_index_max_aio=256 -o rgw_put_obj_max_window_size=134217728 \
-o bluestore_csum_type=none -o rocksdb_cache_size=1073741824 -o rgw_cache_lru_size=1000000 \
-o rgw_get_obj_max_req_size=25165824 -o rgw_get_obj_window_size=25165824 -o rgw_max_chunk_size=25165824 -o rgw_max_listing_results=2000  -o osd_pool_default_pg_num=128 \
-o osd_pool_default_pgp_num=128 -o mon_pg_warn_max_per_osd=10000 -o mon_max_pg_per_osd=9999 -o osd_pool_default_pg_autoscale_mode=warn  -o osd_journal_size=10240 -o osd_max_write_size=512 \
-o osd_map_cache_size=1024 -o osd_op_log_threshold=50  -o bluestore_min_alloc_size=4096 -o bluestore_min_alloc_size_hdd=4096 \
-o bluestore_min_alloc_size_ssd=4096  -o ms_dispatch_throttle_bytes=1048576000 -o ms_crc_data=false -o ms_crc_header=false -o ms_async_op_threads=6 -o ms_async_max_op_threads=16 \
-o objecter_inflight_op_bytes=5368709120 -o objecter_inflight_ops=24576 -o osd_op_num_threads_per_shard=2 -o bluestore_cache_trim_max_skip_pinned=10000   -o osd_pg_log_dups_tracked=10 \
-o osd_pg_log_trim_min=10 -o max_open_files=500000 -o mon_allow_pool_delete=true -o mon_allow_pool_size_one=true -o mutex_perf_counter=false -o throttler_perf_counter=false \
-o bluestore_volume_selection_policy=use_some_extra -o bluestore_default_buffered_read=true -o bluestore_default_buffered_write=false -o bluefs_buffered_io=true \
-o osd_mclock_force_run_benchmark_on_init=1 -o bluestore_allocation_from_file=true -o bluestore_default_buffered_read=true -o bluestore_default_buffered_write=false \
-o bluefs_buffered_io=true -o bluestore_fsck_quick_fix_on_mount=true -o bluestore_fsck_on_mount=false -o bluestore_fsck_on_mount_deep=false \
--rgw_frontend "beast tcp_nodelay=1 request_timeout_ms=0" -o rgw_curl_tcp_keepalive=1  ${VSTART_CONF_PARAMS_MS}  \
-o rgw_list_buckets_max_chunk=999999 -o bluestore_cache_autotune=false -o bluestore_cache_meta_ratio=0.8 -o bluestore_cache_kv_ratio=0.2  -o osd_memory_target_autotune=true \
-o osd_memory_target=8589934592 -o osd_memory_cache_min=4294967296 -o bluestore_cache_size=4294967296 -o bluestore_throttle_bytes=53687091200 \
-o bluestore_throttle_deferred_bytes=107374182400

# BISECT - lower memory usage:
#-o osd_pg_object_context_cache_count=10240
#-o osd_min_pg_log_entries=30000 -o osd_max_pg_log_entries=100000

sudo ./bin/radosgw-admin subuser create --uid=cosbench --subuser=cosbench:operator --secret=redhat --access=full --key-type=swift
sudo ./bin/radosgw-admin user modify --uid=cosbench --max-buckets=0

sudo pgrep -a ceph-osd
sudo /usr/bin/kill --verbose -9 $(ps -ef | grep 'build\/bin\/ceph-osd' | awk '{ print $2 }') ; sleep 1.6
sudo numactl -N 1 -m 1 -- env TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES=${TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES} TCMALLOC_RELEASE_RATE=${TCMALLOC_RELEASE_RATE} GLIBC_TUNABLES="glibc.elision.enable=${GEE}"  /usr/local/bin/eatmydata ./bin/ceph-osd -i 0 -c ./ceph.conf ; sleep 1.5
numactl --hardware
sudo ./bin/ceph osd set noscrub ; sudo ./bin/ceph osd set nodeep-scrub

sudo pgrep -a radosgw
sudo /usr/bin/kill --verbose -9 $(ps -ef | grep 'bin\/radosgw' | grep "800[4567]" | awk '{ print $2 }')
sleep 0.4 ; sudo truncate -s0 ./out/radosgw.8000.log
sudo numactl -N 1 -m 1 -- env TCMALLOC_LARGE_ALLOC_REPORT_THRESHOLD=268435456 TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES=${TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES} TCMALLOC_AGGRESSIVE_DECOMMIT=${TCMALLOC_AGGRESSIVE_DECOMMIT}  TCMALLOC_RELEASE_RATE=${TCMALLOC_RELEASE_RATE}   /usr/local/bin/eatmydata ./bin/radosgw  --nolockdep -c ./ceph.conf --log-file=./out/radosgw.8004.log --admin-socket=./out/radosgw.8004.asok --pid-file=./out/radosgw.8004.pid -n client.rgw.8004 --rgw_frontends="beast port=8004 tcp_nodelay=1 request_timeout_ms=0"  # -f --default-log-to-file=true --default-log-to-stderr=false

pgrep -a ceph ; pgrep -a rados

#sudo pgrep -a haproxy ; sudo pkill haproxy
tee ./haproxy.cfg << EOF
global
  log stdout  format raw  local0  info
  #log stdout  local0  debug
  spread-checks 3
defaults
  #maxconn 3000
  log global
  option httplog
  mode http
  option dontlognull
  mode http
    option forwardfor   	except 127.0.0.0/8
    timeout queue 100
    ##no option http-keep-alive
    ##option httpclose
    option http-keep-alive
    option http-server-close
	timeout client-fin 1s
	timeout server-fin 1s
    timeout client 		 30s
    timeout server 		 30s
    timeout http-request    10s
    timeout connect		 10s  # TODO: 5s & 20s
    timeout check  		 10s  # TODO: 5s & 20s
    timeout http-keep-alive 10s
frontend stats
	bind *:8505
	stats enable
	stats uri /stats
	stats refresh 10s
	stats admin if TRUE
	maxconn 256
frontend http_S3
  #maxconn 6000
  maxconn 6000
  bind *:8200
  option forwardfor
  default_backend rgw
backend rgw
  fullconn 6000
  option redispatch 1
  retry-on all-retryable-errors
  retries 2
  #max-keep-alive-queue 1
  option httpchk
  http-check send meth GET uri /swift/healthcheck
  balance roundrobin
  #balance first
  default-server check maxconn 2000 observe layer7  #error-limit 1  on-error mark-down  inter 1s downinter 5s rise 3 fall 2 maxqueue 1
  server  rgw8005 127.0.0.1:8005
  server  rgw8006 127.0.0.1:8006
  server  rgw8007 127.0.0.1:8007
EOF
#sudo numactl -N 1 -m 1 -- haproxy -f ./haproxy.cfg -D #-d
sudo numactl -N 1 -m 1 -- /usr/local/sbin/haproxy -f ./haproxy.cfg &> haproxy.log &


sudo ./bin/radosgw-admin realm pull --url=http://127.0.0.1:8100 --access-key m2345678901234567890 --secret m234567890123456789012345678901234567890 --default
sudo ./bin/radosgw-admin period pull --url=http://127.0.0.1:8100 --access-key m2345678901234567890 --secret m234567890123456789012345678901234567890 --default
sudo ./bin/radosgw-admin zone create --rgw-zonegroup=us --rgw-zone=us-west --endpoints=http://127.0.0.1:8200 --access-key=m2345678901234567890 --secret=m234567890123456789012345678901234567890 --default
sudo ./bin/radosgw-admin period update --commit


pgrep -a rados
sudo /usr/bin/kill --verbose -9 $(ps -ef | grep 'bin\/radosgw' | grep "800[4567]" | awk '{ print $2 }')
sleep 2 ; date
# hsbench client RGW
sudo numactl -N 1 -m 1 -- env TCMALLOC_LARGE_ALLOC_REPORT_THRESHOLD=268435456 TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES=${TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES} TCMALLOC_AGGRESSIVE_DECOMMIT=${TCMALLOC_AGGRESSIVE_DECOMMIT}  TCMALLOC_RELEASE_RATE=${TCMALLOC_RELEASE_RATE} GLIBC_TUNABLES="glibc.elision.enable=${GEE}"  /usr/local/bin/eatmydata ./bin/radosgw  --nolockdep -c ./ceph.conf --log-file=./out/radosgw.8004.log --admin-socket=./out/radosgw.8004.asok --pid-file=./out/radosgw.8004.pid -n client.rgw.8004 --rgw_frontends="beast port=8004 tcp_nodelay=1 request_timeout_ms=0" --rgw_dynamic_resharding=1 --rgw_run_sync_thread=0 # -f --default-log-to-file=true --default-log-to-stderr=false
# sync RGW
sudo numactl -N 1 -m 1 -- env TCMALLOC_LARGE_ALLOC_REPORT_THRESHOLD=268435456 TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES=${TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES} TCMALLOC_AGGRESSIVE_DECOMMIT=${TCMALLOC_AGGRESSIVE_DECOMMIT}  TCMALLOC_RELEASE_RATE=${TCMALLOC_RELEASE_RATE} GLIBC_TUNABLES="glibc.elision.enable=${GEE}"  /usr/local/bin/eatmydata ./bin/radosgw  --nolockdep -c ./ceph.conf --log-file=./out/radosgw.8005.log --admin-socket=./out/radosgw.8005.asok --pid-file=./out/radosgw.8005.pid -n client.rgw.8005 --rgw_frontends="beast port=8005 tcp_nodelay=1 request_timeout_ms=0" --rgw_dynamic_resharding=1 --rgw_run_sync_thread=1 --rgw_bucket_index_transaction_instrumentation=false --rgw_cache_enabled=true # -f
# sync RGW
sudo numactl -N 1 -m 1 -- env TCMALLOC_LARGE_ALLOC_REPORT_THRESHOLD=268435456 TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES=${TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES} TCMALLOC_AGGRESSIVE_DECOMMIT=${TCMALLOC_AGGRESSIVE_DECOMMIT}  TCMALLOC_RELEASE_RATE=${TCMALLOC_RELEASE_RATE} GLIBC_TUNABLES="glibc.elision.enable=${GEE}"  /usr/local/bin/eatmydata ./bin/radosgw  --nolockdep -c ./ceph.conf --log-file=./out/radosgw.8006.log --admin-socket=./out/radosgw.8006.asok --pid-file=./out/radosgw.8006.pid -n client.rgw.8006 --rgw_frontends="beast port=8006 tcp_nodelay=1 request_timeout_ms=0" --rgw_dynamic_resharding=1 --rgw_run_sync_thread=1 --rgw_bucket_index_transaction_instrumentation=false --rgw_cache_enabled=true # -f
# sync RGW
sudo numactl -N 1 -m 1 -- env TCMALLOC_LARGE_ALLOC_REPORT_THRESHOLD=268435456 TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES=${TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES} TCMALLOC_AGGRESSIVE_DECOMMIT=${TCMALLOC_AGGRESSIVE_DECOMMIT}  TCMALLOC_RELEASE_RATE=${TCMALLOC_RELEASE_RATE} GLIBC_TUNABLES="glibc.elision.enable=${GEE}"  /usr/local/bin/eatmydata ./bin/radosgw  --nolockdep -c ./ceph.conf --log-file=./out/radosgw.8007.log --admin-socket=./out/radosgw.8007.asok --pid-file=./out/radosgw.8007.pid -n client.rgw.8007 --rgw_frontends="beast port=8007 tcp_nodelay=1 request_timeout_ms=0" --rgw_dynamic_resharding=1 --rgw_run_sync_thread=1 --rgw_bucket_index_transaction_instrumentation=false --rgw_cache_enabled=true # -f


date ; pgrep -a rados
 

date ; s3cmd -c ${S3CFG_PATH_MS} --host=127.0.0.1:8004 ls

sleep 17.5 ; date ; s3cmd -c ${S3CFG_PATH_MS} --host=127.0.0.1:8000 put ./ceph.conf s3://b01b000000000000 ; sleep 17.5
date ; sudo ./bin/radosgw-admin bucket sync checkpoint --bucket b01b000000000000 --timeout-sec=3600
date ; s3cmd -c ${S3CFG_PATH_MS} --host=127.0.0.1:8000 rm s3://b01b000000000000/ceph.conf
date ; sudo ./bin/radosgw-admin bucket sync checkpoint --bucket b01b000000000000 --timeout-sec=3600
date ; s3cmd -c ${S3CFG_PATH_MS} --host=127.0.0.1:8000 rm s3://b01b000000000000/ceph.conf  # req b/c bug on 'main' branch

pgrep -a ceph ; pgrep -a haproxy ; pgrep -a rados

ls -b1tr ./out/radosgw*.asok | xargs -i echo {}
ls -b1tr ./out/radosgw*.asok | xargs -i sudo ./bin/ceph --admin-daemon {} config show | egrep "rgw_run_sync_thread|rgw_data_log_num_shards|rgw_md_log_max_shards|rgw_data_notify_interval_msec|rgw_default_data_log_backing|rgw_sync_lease_period|rgw_dynamic_resharding|rgw_reshard_thread_interval|rgw_max_objs_per_shard|rgw_sync_log_trim_interval|rgw_bucket_index_transaction_instrumentation|rgw_data_log_window|rgw_curl_low_speed_time|rgw_cache_enabled|rgw_override_bucket_index_max_shards|rgw_thread_pool_size|rgw_max_concurrent_requests|rgw_max_dynamic_shards|rgw_resharding_multiplier_multisite"
date


ls -b1tr ./out/radosgw*.asok | xargs -i  sudo ./bin/ceph --admin-daemon {} config set debug_ms "${DEBUG_MS}"
ls -b1tr ./out/radosgw*.asok | xargs -i  sudo ./bin/ceph --admin-daemon {} config set debug_rgw "${DEBUG_RGW}"
ls -b1tr ./out/radosgw*.asok | xargs -i  sudo ./bin/ceph --admin-daemon {} config set debug_rgw_sync "${DEBUG_RGW_SYNC}"

ls -b1tr ./out/radosgw*.asok | xargs -i  sudo ./bin/ceph --admin-daemon {} config set debug_objclass "${DEBUG_OBJCLASS}"
sudo ./bin/ceph tell "osd.*" injectargs --debug_objclass "${DEBUG_OBJCLASS}" #; sudo truncate -s0 ./out/osd.0.log

set +x
