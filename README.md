# 离线内网 Nexus 镜像源搭建（pip + npm）

让离线服务器上的工具平台在「生成脚本 / 安装依赖」时，自动从内网 Nexus 拉取 Python 和 Node 依赖。

## 架构

```
[联网机器]                         [离线服务器(Nexus)]              [平台/客户端]
 download-pip.sh   --scp-->   import-pip.sh  -> pypi-hosted
 download-npm.sh   --scp-->   import-npm.sh  -> npm-hosted   <-- pip/npm 走内网源
```

- **联网机器**：负责批量下载包并打包（一条命令下全部依赖，自动解析依赖树）。
- **离线服务器**：跑 Nexus，把包对内网提供。
- **客户端**：就是平台所在的服务器，改 pip/npm 源指向 Nexus 即可，平台生成什么 `pip install`/`npm install` 都会自动走内网。

## 目录说明

```
offline-server/      离线服务器上用
  install-nexus-tarball.sh   ★ 用压缩包安装 Nexus（不需要 Docker，推荐）
  docker-compose.yml         可选：如果服务器有 Docker 也可以用这个
  setup-nexus-repos.sh       创建 pypi-hosted / npm-hosted 仓库
  import-pip.sh              导入 pip 包
  import-npm.sh              导入 npm 包
online-machine/      联网机器上用
  download-nexus.sh          ★ 下载 Nexus 安装包（普通 HTTPS 下载，不需要 Docker）
  download-pip.sh            下载并打包 pip 依赖
  download-npm.sh            下载并打包 npm 依赖
common-packages/     常用包清单（按需增删）
  pip-common.txt
  npm-common.txt
client-config/       客户端源配置模板
  pip.conf
  .npmrc
```

---

## 安装方式：两选一

### 方式 A：压缩包安装（推荐，不需要 Docker）★

适用于"联网机不能用 Docker"或"不想依赖 Docker"的情况。
Nexus 官方提供原生 Linux 压缩包，**较新版本自带 Java 运行时，离线服务器连 Java 都不用装**。

### 方式 B：Docker 安装（仅当两边都能用 Docker 时）

用 `offline-server/docker-compose.yml`。需要在联网机 `docker pull sonatype/nexus3` →
`docker save` 成 tar → scp → 离线服务器 `docker load`。本文档主线按方式 A 写。

---

## 前置准备

1. **Python3 / Node+npm**：离线服务器上要有这俩运行时（导入脚本和客户端都要用）。
   若平台机器本身没有，也需要离线安装。
2. **Nexus 不能用 root 运行**：`install-nexus-tarball.sh` 会自动建一个 `nexus` 用户。
3. **联网机和离线服务器的 OS/架构/Python 版本最好一致**（影响 wheel 是否可用，见下方说明）。

---

## 操作步骤

### 第 1 步：在离线服务器部署 Nexus（压缩包方式）

```bash
# (1) 在联网机下载 Nexus 安装包（普通 HTTPS 下载，不需要 Docker）
cd online-machine
./download-nexus.sh          # 产出 nexus-unix.tar.gz
```
> 也可以直接用浏览器/curl 下载（x86-64 Linux）：
> - 最新版：`https://download.sonatype.com/nexus/3/latest-linux-x86_64.tar.gz`
> - 锁定版本：`https://download.sonatype.com/nexus/3/nexus-3.93.2-01-linux-x86_64.tar.gz`
> - ARM64 / 其他平台见 https://help.sonatype.com/en/download.html
> 安装包自带对应平台的 JDK，离线服务器不用单独装 Java。
```bash
# (2) scp 到离线服务器
scp nexus-unix.tar.gz user@离线服务器:/path/to/offline-server/

# (3) 在离线服务器安装并启动
cd offline-server
sudo ./install-nexus-tarball.sh nexus-unix.tar.gz
# 按提示后台启动:
sudo -u nexus /opt/nexus/nexus-3*/bin/nexus start
```
等 2~3 分钟首次初始化。浏览器访问 `http://离线服务器IP:7012`。
初始 admin 密码在 `/opt/nexus/sonatype-work/nexus3/admin.password`，
用 `admin` + 该密码登录，按提示改密码（假设改成 `admin123`）。
> 登录后建议开启 "Enable anonymous access"，这样客户端拉包不用配账号（仅拉取，发布仍需账号）。

### 第 2 步：创建仓库

```bash
# 把脚本里的 NEXUS_PASS 改成你的新密码，或用环境变量传入
NEXUS_PASS='你的密码' ./setup-nexus-repos.sh
```
完成后会有两个仓库：
- `http://离线服务器IP:7012/repository/pypi-hosted/`
- `http://离线服务器IP:7012/repository/npm-hosted/`

### 第 3 步：在联网机器下载依赖

#### Linux / Mac（用 bash 脚本）

```bash
cd online-machine

# pip：默认已是与你环境对齐的组合 Python 3.13 + x86_64 Linux，直接跑即可
./download-pip.sh ../common-packages/pip-common.txt
# （若离线服务器是 ARM 或其他 Python 版本，才需要覆盖，例如：
#   PYVER=312 PLATFORM=manylinux2014_aarch64 ./download-pip.sh ../common-packages/pip-common.txt ）
# 产出 pip-packages.tar.gz

# npm：
./download-npm.sh ../common-packages/npm-common.txt
# 产出 npm-packages.tar.gz
```

#### Windows（用 PowerShell 脚本，不需要 bash）

需要联网机已装 Python 和 Node（Node 去 nodejs.org 下 LTS）。Windows 10/11 自带 `tar`。

```powershell
cd online-machine

# 如遇执行策略限制，先放开本进程:
Set-ExecutionPolicy -Scope Process Bypass

# pip 依赖（默认目标 Python 3.13 + x86_64 Linux）
.\download-pip.ps1          # 产出 pip-packages.tar.gz

# npm 依赖
.\download-npm.ps1          # 产出 npm-packages.tar.gz
```
然后用 WinSCP / scp 把两个 .tar.gz 传到离线服务器的 /root/BYX/。

### 第 4 步：scp 传到离线服务器

```bash
scp pip-packages.tar.gz npm-packages.tar.gz user@离线服务器:/path/to/offline-server/
```

### 第 5 步：在离线服务器导入

```bash
cd offline-server
tar xzf pip-packages.tar.gz
tar xzf npm-packages.tar.gz

# 注意：import-pip.sh 需要 twine。如果系统还没有 twine，
# 先从解压出的 pip-packages/ 里手动装：
#   pip install --no-index --find-links=pip-packages twine
NEXUS_PASS='你的密码' ./import-pip.sh pip-packages
NEXUS_PASS='你的密码' ./import-npm.sh npm-packages
```

### 第 6 步：配置客户端（平台所在服务器）

把 `client-config/` 里的模板改好 `NEXUS_HOST`，放到对应位置：

```bash
# pip（全局）
cp client-config/pip.conf /etc/pip.conf
sed -i 's/NEXUS_HOST/离线服务器IP/g' /etc/pip.conf

# npm（全局，路径以 npm config get globalconfig 为准；或放 ~/.npmrc）
cp client-config/.npmrc ~/.npmrc
sed -i 's/NEXUS_HOST/离线服务器IP/g' ~/.npmrc
```

### 第 7 步：验证

```bash
pip install requests        # 应从 pypi-hosted 拉取成功
npm install lodash          # 应从 npm-hosted 拉取成功
```
这之后，平台生成的任何安装脚本都会自动走你的内网镜像。

---

## 日后"缺啥补啥"

平台运行时如果提示缺某个包：
1. 把包名加到 `common-packages/*.txt`（或临时单独下）。
2. 在联网机重跑对应 `download-*.sh`。
3. scp 过去，重跑 `import-*.sh`（脚本会自动跳过已存在的包）。

---

## 关于 wheel 平台匹配（pip 最常见的坑）

`pip download` 默认只下与「当前机器」匹配的 wheel。如果联网机是 Mac/Windows、离线服务器是 Linux，直接下的包装不上。
`download-pip.sh` 已用 `--platform`/`--python-version` 强制按目标平台下载。

**默认已选用与你环境对齐的组合：Python 3.13 + x86_64 Linux**
（`PYVER=313` + `PLATFORM=manylinux2014_x86_64`）。
如果你的离线服务器就是 x86_64 Linux + Python 3.13，**直接用默认值即可，无需改动**。

只有当离线服务器不是这个组合时才需要改：
- ARM64 Linux：`PLATFORM=manylinux2014_aarch64`
- 其他 Python 版本：3.11 → `PYVER=311`，3.12 → `PYVER=312`，以此类推。

> 提示：Python 3.13 较新，极少数库可能还没发布对应 wheel；脚本已自动用源码包(sdist)兜底，必要时离线服务器上需有编译环境(gcc 等)。
