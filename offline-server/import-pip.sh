#!/usr/bin/env bash
#
# 在【离线服务器】上运行：把 scp 过来的 pip 包批量上传到 Nexus pypi-hosted。
# 依赖：python3 + twine（twine 也在常用清单里，可先单独装一个）。
#
# 用法:
#   tar xzf pip-packages.tar.gz          # 解出 pip-packages/ 目录
#   ./import-pip.sh pip-packages
#
set -euo pipefail

PKG_DIR="${1:-pip-packages}"

# ===== 改成你的 Nexus 实际地址/账号 =====
NEXUS_URL="${NEXUS_URL:-http://localhost:7012}"
NEXUS_USER="${NEXUS_USER:-admin}"
NEXUS_PASS="${NEXUS_PASS:-admin123}"
# =====================================

REPO_URL="${NEXUS_URL}/repository/pypi-hosted/"

if ! command -v twine >/dev/null 2>&1; then
  echo "!! 未找到 twine。请先离线安装 twine（在 pip-packages 里找到 twine/setuptools/wheel/pkginfo 等手动 pip install）。"
  exit 1
fi

echo ">> 上传 ${PKG_DIR}/ 下所有包到 ${REPO_URL} ..."
# --skip-existing 让重复上传不报错
TWINE_USERNAME="${NEXUS_USER}" \
TWINE_PASSWORD="${NEXUS_PASS}" \
twine upload \
  --repository-url "${REPO_URL}" \
  --skip-existing \
  --non-interactive \
  "${PKG_DIR}"/*

echo ">> 完成。"
