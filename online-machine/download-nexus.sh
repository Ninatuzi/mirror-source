#!/usr/bin/env bash
#
# 在【联网机器】上运行：下载 Nexus 的原生 Linux 压缩包（不需要 Docker）。
# 依赖：curl（或 wget）。这只是一个普通 HTTPS 下载。
#
# 下载后把 nexus-unix.tar.gz scp 到离线服务器，再用 install-nexus-tarball.sh 安装。
#
set -euo pipefail

OUT="nexus-unix.tar.gz"

# Sonatype 官方下载地址（自带平台 JDK，无需另装 Java）。
# 注意：Sonatype 已按 CPU 架构拆包，旧的 latest-unix.tar.gz 已失效。
# 默认用 x86-64 的「最新版」指针；如需锁定版本，把 URL 换成带版本号的链接，例如：
#   https://download.sonatype.com/nexus/3/nexus-3.93.2-01-linux-x86_64.tar.gz
# ARM64 服务器请去官方下载页取对应链接：https://help.sonatype.com/en/download.html
URL="${NEXUS_URL:-https://download.sonatype.com/nexus/3/latest-linux-x86_64.tar.gz}"

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
