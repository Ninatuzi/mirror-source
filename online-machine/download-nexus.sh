#!/usr/bin/env bash
#
# 在【联网机器】上运行：下载 Nexus 的原生 Linux 压缩包（不需要 Docker）。
# 依赖：curl（或 wget）。这只是一个普通 HTTPS 下载。
#
# 下载后把 nexus-unix.tar.gz scp 到离线服务器，再用 install-nexus-tarball.sh 安装。
#
set -euo pipefail

OUT="nexus-unix.tar.gz"

# Sonatype 官方「最新版」稳定下载地址（自带 JRE，无需另装 Java）
URL="${NEXUS_URL:-https://download.sonatype.com/nexus/3/latest-unix.tar.gz}"

echo ">> 下载 Nexus 压缩包: ${URL}"
if command -v curl >/dev/null 2>&1; then
  curl -fL "${URL}" -o "${OUT}"
elif command -v wget >/dev/null 2>&1; then
  wget -O "${OUT}" "${URL}"
else
  echo "!! 没有 curl 也没有 wget，请手动用浏览器下载：${URL}"
  exit 1
fi

echo
echo ">> 完成: ${OUT}  ($(du -h "${OUT}" | cut -f1))"
echo ">> 下一步: scp ${OUT} 到离线服务器，然后运行 install-nexus-tarball.sh"
