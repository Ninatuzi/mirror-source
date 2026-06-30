#!/usr/bin/env bash
#
# 在【离线服务器】上运行：把 scp 过来的 .tgz 批量发布到 Nexus npm-hosted。
# 依赖：node + npm。
#
# 用法:
#   tar xzf npm-packages.tar.gz          # 解出 npm-packages/ 目录
#   ./import-npm.sh npm-packages
#
set -euo pipefail

PKG_DIR="${1:-npm-packages}"

# ===== 改成你的 Nexus 实际地址/账号 =====
NEXUS_URL="${NEXUS_URL:-http://localhost:7012}"
NEXUS_USER="${NEXUS_USER:-admin}"
NEXUS_PASS="${NEXUS_PASS:-admin123}"
# =====================================

REGISTRY="${NEXUS_URL}/repository/npm-hosted/"

echo ">> 登录 Nexus npm 仓库 ..."
# Nexus 接受 base64(user:pass) 形式的 _auth；这里生成一个临时 .npmrc
HOST_NOPROTO="$(echo "${NEXUS_URL}" | sed -E 's#^https?://##')"
AUTH="$(echo -n "${NEXUS_USER}:${NEXUS_PASS}" | base64)"
TMP_NPMRC="$(mktemp)"
cat > "${TMP_NPMRC}" <<EOF
registry=${REGISTRY}
//${HOST_NOPROTO}/repository/npm-hosted/:_auth=${AUTH}
email=admin@example.com
always-auth=true
EOF

echo ">> 逐个 publish ${PKG_DIR}/*.tgz ..."
ok=0; fail=0
for tgz in "${PKG_DIR}"/*.tgz; do
  if npm publish "${tgz}" --userconfig "${TMP_NPMRC}" --registry "${REGISTRY}" >/dev/null 2>&1; then
    echo "   ok: $(basename "${tgz}")"
    ok=$((ok+1))
  else
    # 已存在的会失败，属正常
    echo "   skip/fail: $(basename "${tgz}")"
    fail=$((fail+1))
  fi
done

rm -f "${TMP_NPMRC}"
echo ">> 完成。成功 ${ok}，跳过/失败 ${fail}（已存在的包会被跳过，属正常）。"
