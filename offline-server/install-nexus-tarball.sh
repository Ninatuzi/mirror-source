#!/usr/bin/env bash
#
# 在【离线服务器】上运行：从 scp 过来的 nexus-unix.tar.gz 安装并启动 Nexus。
# 不需要 Docker。较新版本的 Nexus 自带 JRE，连 Java 都不用装。
#
# 用法:
#   ./install-nexus-tarball.sh nexus-unix.tar.gz
#
set -euo pipefail

TARBALL="${1:-nexus-unix.tar.gz}"
INSTALL_DIR="${INSTALL_DIR:-/opt/nexus}"

if [ ! -f "${TARBALL}" ]; then
  echo "!! 找不到 ${TARBALL}，请确认已 scp 到当前目录"
  exit 1
fi

echo ">> 解压到 ${INSTALL_DIR} ..."
mkdir -p "${INSTALL_DIR}"
# 用 tar xf（不带 z）：GNU tar 会自动识别 gzip 或普通 tar，
# 兼容 .tar.gz 和被解过 gzip 的 .tar 两种情况。
tar xf "${TARBALL}" -C "${INSTALL_DIR}"

# 解压后会有两个目录：
#   nexus-3.x.x-xx/      程序本体（bin、etc 等）
#   sonatype-work/       数据目录（仓库内容、配置、初始密码）
NEXUS_HOME="$(find "${INSTALL_DIR}" -maxdepth 1 -type d -name 'nexus-3*' | head -n1)"
if [ -z "${NEXUS_HOME}" ]; then
  echo "!! 没找到 nexus-3* 目录，解压可能有问题"
  exit 1
fi
echo ">> Nexus 程序目录: ${NEXUS_HOME}"

# Nexus 默认不允许用 root 运行。建议建一个专用用户。
if id nexus >/dev/null 2>&1; then
  echo ">> 用户 nexus 已存在"
else
  echo ">> 创建 nexus 用户 ..."
  useradd -r -m -d /home/nexus -s /bin/bash nexus || true
fi
chown -R nexus:nexus "${INSTALL_DIR}"

# 让 Nexus 以 nexus 用户运行
echo 'run_as_user="nexus"' > "${NEXUS_HOME}/bin/nexus.rc"

# 设置监听端口为 7012（默认是 8081）
NEXUS_PORT="${NEXUS_PORT:-7012}"
echo ">> 设置 Nexus 监听端口为 ${NEXUS_PORT} ..."
PROP_DIR="${INSTALL_DIR}/sonatype-work/nexus3/etc"
mkdir -p "${PROP_DIR}"
PROP_FILE="${PROP_DIR}/nexus.properties"
touch "${PROP_FILE}"
if grep -q '^application-port=' "${PROP_FILE}" 2>/dev/null; then
  sed -i "s/^application-port=.*/application-port=${NEXUS_PORT}/" "${PROP_FILE}"
else
  echo "application-port=${NEXUS_PORT}" >> "${PROP_FILE}"
fi
chown -R nexus:nexus "${INSTALL_DIR}/sonatype-work"

echo
echo ">> 安装完成。启动方式（任选其一）："
echo
echo "   前台运行（调试用，Ctrl+C 停止）:"
echo "     sudo -u nexus ${NEXUS_HOME}/bin/nexus run"
echo
echo "   后台运行:"
echo "     sudo -u nexus ${NEXUS_HOME}/bin/nexus start"
echo "     # 停止: sudo -u nexus ${NEXUS_HOME}/bin/nexus stop"
echo
echo ">> 首次启动约 2~3 分钟。Web 界面: http://本机IP:${NEXUS_PORT}"
echo ">> 初始 admin 密码在: ${INSTALL_DIR}/sonatype-work/nexus3/admin.password"
echo
echo ">> 启动并改完密码后，运行 setup-nexus-repos.sh 创建 pip/npm 仓库。"
