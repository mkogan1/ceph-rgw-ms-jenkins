#!/usr/bin/env bash
set -e
source /opt/rh/gcc-toolset-12/enable

if [[ -z "${GITHUB_REMOTE}" ]]; then  exit 1  ; fi
echo "  >> env GITHUB_REMOTE = ${GITHUB_REMOTE}"
if [[ -z "${GITHUB_BRANCH}" ]]; then  exit 1  ; fi
echo "  >> env GITHUB_BRANCH = ${GITHUB_BRANCH}"
if [[ -z "${MS_ZONE}" ]]; then  exit 1  ; fi
echo "  >> env MS_ZONE = ${MS_ZONE}"
if [[ -z "${SRC_DIR_MS}" ]]; then  SRC_DIR_MS="/mnt/raid0/src/ceph--jenkins-01--MS"  ; fi
echo "  >> env SRC_DIR_MS = ${SRC_DIR_MS}"

echo "  > id = $(id)"
echo "  > pwd = $(pwd)"
echo "  > g++ --version = $(g++ --version)"

set -x

BLD_DIR=${SRC_DIR_MS}${MS_ZONE}
echo "  >> env BLD_DIR = ${BLD_DIR}"
#exit 1

set -x

sudo chmod a+rwx "$(dirname ${SRC_DIR_MS})"
#exit 1

sudo rm -rf "${BLD_DIR}"
#git clone "${GITHUB_REMOTE}" --branch "${GITHUB_BRANCH}" -c core.compression=5 -c core.loosecompression=5 --jobs="$(nproc)" --recursive --progress "${BLD_DIR}" 2>&1
git clone "${GITHUB_REMOTE}" --branch "${GITHUB_BRANCH}" -c core.compression=3 -c core.loosecompression=3 --jobs="$(nproc)" --recursive "${BLD_DIR}" 2>&1

cd "${BLD_DIR}" || exit
export USELD="bfd" ; export CSLF="bfd"
./do_cmake.sh -DCMAKE_EXPORT_COMPILE_COMMANDS=1 -DDIAGNOSTICS_COLOR=never -DBOOST_J="$(nproc)" -DWITH_MGR_DASHBOARD_FRONTEND:BOOL=OFF \
-DWITH_SEASTAR=OFF -DWITH_DPDK=OFF -DWITH_SPDK=OFF -DWITH_CEPHFS=ON -DWITH_LIBCEPHFS=ON -DWITH_RBD=OFF -DWITH_KRBD=OFF \
-DWITH_MANPAGE=OFF -DWITH_LTTNG=OFF -DWITH_BABELTRACE=OFF -DWITH_SELINUX=OFF -DWITH_OCF=OFF -DWITH_GRAFANA=OFF \
-DWITH_FUSE=OFF -DWITH_RDMA=OFF -DWITH_OPENLDAP=OFF -DWITH_SYSTEMD=OFF -DWITH_LIBRADOSSTRIPER=OFF -DWITH_LEVELDB=OFF \
-DWITH_RADOSGW_AMQP_ENDPOINT=OFF -DWITH_RADOSGW_KAFKA_ENDPOINT=OFF -DWITH_LZ4=ON -DWITH_JAEGER=OFF -DWITH_FIO=OFF \
-DWITH_RADOSGW_DBSTORE=ON -DWITH_KVS=OFF -DWITH_MGR_ROOK_CLIENT=OFF -DWITH_LIBCEPHSQLITE=OFF -DWITH_CEPH_DEBUG_MUTEX=OFF \
-DWITH_RADOSGW_BEAST_OPENSSL=ON -DWITH_EC_ISA_PLUGIN=OFF -DWITH_RADOSGW_LUA_PACKAGES=ON -DWITH_XFS=OFF -DWITH_RADOSGW_SELECT_PARQUET=OFF \
-DWITH_CCACHE=OFF \
-DCMAKE_CXX_FLAGS="-Wp,-D_GLIBCXX_ASSERTIONS -fstack-clash-protection -pipe -frecord-gcc-switches -grecord-gcc-switches \
-fno-omit-frame-pointer -fstack-protector-strong -ggdb3 -gdwarf-4 -Ofast -fcf-protection=none -Warray-bounds \
-Wp,-D_FORTIFY_SOURCE=2 -march=native -mavx2 -mfma -ffp-contract=fast -ffast-math -mfpmath=sse --param=ssp-buffer-size=16" \
-DCMAKE_C_FLAGS="-pipe -frecord-gcc-switches -grecord-gcc-switches -fno-omit-frame-pointer -fstack-protector-strong \
-ggdb3 -gdwarf-4 -Ofast -Warray-bounds \
-Wp,-D_FORTIFY_SOURCE=2 -march=native -mavx2 -mfma -ffp-contract=fast -ffast-math -mfpmath=sse --param=ssp-buffer-size=16" \
-G "Unix Makefiles" -DALLOCATOR=tcmalloc -DCMAKE_BUILD_TYPE=RelWithDebInfo -DWITH_LIBURING=ON -DWITH_TESTS=OFF \
-DENABLE_GIT_VERSION=ON -DCMAKE_MODULE_LINKER_FLAGS="-fuse-ld=${USELD} -v" -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=${USELD} -v" \
-DCMAKE_SHARED_LINKER_FLAGS="-fuse-ld=${CSLF} -v" -DWITH_SYSTEM_BOOST=OFF -DWITH_BOOST_VALGRIND=ON

time nice ionice cmake --build ./build --parallel "$(nproc --ignore=1)" -- vstart


set +x

#exit 0
