#!/usr/bin/env bash
#
# 在【联网机器】上运行：把清单里的包连同全部间接依赖下载下来并打包。
# 依赖：python3 + pip。
#
# 用法:
#   ./download-pip.sh ../common-packages/pip-common.txt
#
# 重要 —— 平台匹配：
#   pip 下载的是与"当前机器"匹配的 wheel。如果联网机和离线服务器的
#   操作系统/架构/Python 版本不一致，装的时候可能用不了。
#   下面默认按 manylinux + 指定 Python 版本下载，确保在离线 Linux 服务器可用。
#   请把 PYVER / PLATFORM 改成离线服务器的真实情况。
#
set -euo pipefail

REQ_FILE="${1:-../common-packages/pip-common.txt}"
OUT_DIR="pip-packages"

# ===== 改成离线服务器的实际情况 =====
PYVER="${PYVER:-311}"                         # 离线服务器的 Python 版本，如 3.11 -> 311
PLATFORM="${PLATFORM:-manylinux2014_x86_64}"  # x86_64 用这个；ARM 用 manylinux2014_aarch64
# ==================================

mkdir -p "${OUT_DIR}"

echo ">> 下载二进制 wheel（按目标平台 ${PLATFORM}, py${PYVER}）..."
# --only-binary :all: 强制只下 wheel，配合 --platform 实现跨平台下载
pip download \
  -r "${REQ_FILE}" \
  -d "${OUT_DIR}" \
  --only-binary=:all: \
  --platform "${PLATFORM}" \
  --python-version "${PYVER}" \
  --implementation cp \
  || echo "!! 部分包没有匹配 wheel，下面再补源码包"

echo ">> 补充下载源码包（sdist），覆盖纯 Python / 无 wheel 的包 ..."
pip download \
  -r "${REQ_FILE}" \
  -d "${OUT_DIR}" \
  --no-binary=:all: \
  --no-deps \
  || true

echo ">> 打包 ..."
tar czf pip-packages.tar.gz "${OUT_DIR}"

echo
echo ">> 完成: pip-packages.tar.gz"
echo "   共 $(ls -1 ${OUT_DIR} | wc -l) 个文件, 大小 $(du -sh ${OUT_DIR} | cut -f1)"
echo ">> 下一步: scp pip-packages.tar.gz 到离线服务器"
