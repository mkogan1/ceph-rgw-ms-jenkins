#!/usr/bin/env bash
#set -e
source /opt/rh/gcc-toolset-12/enable

if [[ -z "${SRC_DIR_MS}" ]]; then  SRC_DIR_MS="/mnt/raid0/src/ceph--jenkins-01--MS"  ; fi
echo "  >> env SRC_DIR_MS = ${SRC_DIR_MS}"
if [[ -z "${HSBENCH_FROM_STAGE}" ]]; then  HSBENCH_FROM_STAGE=1  ; fi
echo "  >> env HSBENCH_FROM_STAGE = ${HSBENCH_FROM_STAGE}"
if [[ -z "${HSBENCH_TO_STAGE}" ]]; then  HSBENCH_TO_STAGE=16  ; fi
echo "  >> env HSBENCH_TO_STAGE = ${HSBENCH_TO_STAGE}"

DIRNAME=$(dirname "${0}")
echo "  > DIRNAME=${DIRNAME}"
echo "  > id = $(id)"
echo "  > pwd = $(pwd)"
echo "  > g++ --version = $(g++ --version)"


for STAGE in $(seq ${HSBENCH_FROM_STAGE} ${HSBENCH_TO_STAGE}); do
  echo "***************************************************************************************************"
  echo "Execute STAGE = ${STAGE}"
  echo "***************************************************************************************************"
  timeout 225m env HSBENCH_STAGE=${STAGE} ${DIRNAME}/jenkins_hsbench_MS.sh
done
