#!/usr/bin/env bash
#
# 在【联网机器】上运行：把清单里的 npm 包连同全部传递依赖下载为 .tgz 并打包。
# 依赖：node + npm。
#
# 原理：先用清单生成一个 package.json，npm install 解析出完整依赖树写入
#       package-lock.json，再从 lock 文件里提取所有 tarball URL 逐个下载。
#
# 用法:
#   ./download-npm.sh ../common-packages/npm-common.txt
#
set -euo pipefail

LIST_FILE="${1:-../common-packages/npm-common.txt}"
WORK_DIR="npm-build"
OUT_DIR="npm-packages"

rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}" "${OUT_DIR}"

echo ">> 生成临时 package.json ..."
( cd "${WORK_DIR}" && npm init -y >/dev/null )

# 把清单里的包加入依赖（忽略注释和空行）
pkgs=()
while IFS= read -r line; do
  line="$(echo "$line" | sed 's/#.*//' | xargs || true)"
  [ -z "$line" ] && continue
  pkgs+=("$line")
done < "${LIST_FILE}"

echo ">> 解析依赖树（只生成 lock，不真正装）: ${#pkgs[@]} 个直接依赖 ..."
( cd "${WORK_DIR}" && npm install --package-lock-only --save "${pkgs[@]}" )

echo ">> 从 package-lock.json 提取所有 tarball 地址并下载 ..."
# 提取所有 "resolved": "https://....tgz" 的 URL
grep -oE '"resolved": *"[^"]+\.tgz"' "${WORK_DIR}/package-lock.json" \
  | sed -E 's/.*"(https?:[^"]+)".*/\1/' \
  | sort -u > "${WORK_DIR}/urls.txt"

count=$(wc -l < "${WORK_DIR}/urls.txt")
echo ">> 共 ${count} 个 tarball，开始下载 ..."
while IFS= read -r url; do
  [ -z "$url" ] && continue
  fname="$(basename "$url")"
  # 同名不同包用目录名区分，直接平铺也可，publish 时按内容识别
  if [ ! -f "${OUT_DIR}/${fname}" ]; then
    curl -sfL "$url" -o "${OUT_DIR}/${fname}" && echo "   ok: ${fname}" || echo "   FAIL: ${url}"
  fi
done < "${WORK_DIR}/urls.txt"

echo ">> 打包 ..."
tar czf npm-packages.tar.gz "${OUT_DIR}"

echo
echo ">> 完成: npm-packages.tar.gz"
echo "   共 $(ls -1 ${OUT_DIR} | wc -l) 个 tgz, 大小 $(du -sh ${OUT_DIR} | cut -f1)"
echo ">> 下一步: scp npm-packages.tar.gz 到离线服务器"
