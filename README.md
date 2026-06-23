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
  docker-compose.yml     部署 Nexus
  setup-nexus-repos.sh   创建 pypi-hosted / npm-hosted 仓库
  import-pip.sh          导入 pip 包
  import-npm.sh          导入 npm 包
online-machine/      联网机器上用
  download-pip.sh        下载并打包 pip 依赖
  download-npm.sh        下载并打包 npm 依赖
common-packages/     常用包清单（按需增删）
  pip-common.txt
  npm-common.txt
client-config/       客户端源配置模板
  pip.conf
  .npmrc
```

---

## 前置准备（重要）

离线服务器是隔离的，**这些东西也得先准备好**，别只想着包：

1. **Docker + docker-compose**：离线服务器要能跑容器。若没装，需另行离线安装。
2. **Nexus 镜像本身**：离线服务器拉不了 Docker Hub，所以在联网机上先：
   ```bash
   docker pull sonatype/nexus3:latest
   docker save sonatype/nexus3:latest -o nexus3.tar
   # scp nexus3.tar 到离线服务器后:
   docker load -i nexus3.tar
   ```
3. **Python3 / Node+npm**：离线服务器上要有这俩运行时（导入脚本和客户端都要用）。
   若平台机器本身没有，也需要离线安装。
4. **联网机和离线服务器的 OS/架构/Python 版本最好一致**（影响 wheel 是否可用，见下方说明）。

---

## 操作步骤

### 第 1 步：在离线服务器部署 Nexus

```bash
cd offline-server
docker compose up -d
# 等 2~3 分钟首次初始化。拿初始密码：
docker exec -it nexus cat /nexus-data/admin.password
```
浏览器访问 `http://离线服务器IP:8081`，用 `admin` + 上面的初始密码登录，按提示改密码（假设改成 `admin123`）。
> 登录后建议开启 "Enable anonymous access"，这样客户端拉包不用配账号（仅拉取，发布仍需账号）。

### 第 2 步：创建仓库

```bash
# 把脚本里的 NEXUS_PASS 改成你的新密码，或用环境变量传入
NEXUS_PASS='你的密码' ./setup-nexus-repos.sh
```
完成后会有两个仓库：
- `http://离线服务器IP:8081/repository/pypi-hosted/`
- `http://离线服务器IP:8081/repository/npm-hosted/`

### 第 3 步：在联网机器下载依赖

```bash
cd online-machine

# pip：默认已是稳妥组合 Python 3.11 + x86_64 Linux，直接跑即可
./download-pip.sh ../common-packages/pip-common.txt
# （若离线服务器是 ARM 或其他 Python 版本，才需要覆盖，例如：
#   PYVER=312 PLATFORM=manylinux2014_aarch64 ./download-pip.sh ../common-packages/pip-common.txt ）
# 产出 pip-packages.tar.gz

# npm：
./download-npm.sh ../common-packages/npm-common.txt
# 产出 npm-packages.tar.gz
```

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

**默认已选用稳妥推荐组合：Python 3.11 + x86_64 Linux**
（`PYVER=311` + `PLATFORM=manylinux2014_x86_64`，wheel 覆盖最全、兼容性最好）。
如果你的离线服务器就是 x86_64 Linux，**直接用默认值即可，无需改动**。

只有当离线服务器不是这个组合时才需要改：
- ARM64 Linux：`PLATFORM=manylinux2014_aarch64`
- 其他 Python 版本：3.10 → `PYVER=310`，3.12 → `PYVER=312`，以此类推。
