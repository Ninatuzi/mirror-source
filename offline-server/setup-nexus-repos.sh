#!/usr/bin/env bash
#
# 在 Nexus 启动后运行一次，自动创建 pypi-hosted 和 npm-hosted 两个本地托管仓库。
# 依赖：curl。在离线服务器上执行。
#
# 用法:
#   ./setup-nexus-repos.sh
#
set -euo pipefail

# ===== 可按需修改 =====
NEXUS_URL="${NEXUS_URL:-http://localhost:8081}"
NEXUS_USER="${NEXUS_USER:-admin}"
# 首次启动后的初始密码在容器内 /nexus-data/admin.password，
# 登录 Web UI 改密后，把新密码填到这里或用环境变量传入。
NEXUS_PASS="${NEXUS_PASS:-admin123}"
# =====================

api="${NEXUS_URL}/service/rest/v1"

echo ">> 等待 Nexus 就绪 (${NEXUS_URL}) ..."
until curl -sf "${NEXUS_URL}/service/rest/v1/status" >/dev/null 2>&1; do
  echo "   ...还没起来，5s 后重试"
  sleep 5
done
echo ">> Nexus 已就绪"

create_repo () {
  local name="$1" format="$2"
  echo ">> 创建 ${format} hosted 仓库: ${name}"
  curl -sf -u "${NEXUS_USER}:${NEXUS_PASS}" \
    -X POST "${api}/repositories/${format}/hosted" \
    -H "Content-Type: application/json" \
    -d @- <<JSON || echo "   (可能已存在，跳过)"
{
  "name": "${name}",
  "online": true,
  "storage": {
    "blobStoreName": "default",
    "strictContentTypeValidation": true,
    "writePolicy": "ALLOW"
  }
}
JSON
}

create_repo "pypi-hosted" "pypi"
create_repo "npm-hosted"  "npm"

echo
echo ">> 完成。仓库地址："
echo "   PyPI: ${NEXUS_URL}/repository/pypi-hosted/"
echo "   npm : ${NEXUS_URL}/repository/npm-hosted/"
