# Windows PowerShell 版：下载 pip 依赖并打包（不需要 bash）
# 在【联网的 Windows 机器】上运行。需要已安装 Python + pip。
#
# 用法（在 PowerShell 里，进入 online-machine 目录后）:
#   powershell -ExecutionPolicy Bypass -File .\download-pip.ps1
# 或先放开本进程的执行策略再跑:
#   Set-ExecutionPolicy -Scope Process Bypass
#   .\download-pip.ps1
#
# 默认目标：Python 3.13 + x86_64 Linux（与离线服务器一致）。

param(
    [string]$ReqFile  = "..\common-packages\pip-common.txt",
    [string]$PyVer    = "313",
    [string]$Platform = "manylinux2014_x86_64"
)

$OutDir = "pip-packages"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Write-Host ">> 下载二进制 wheel (目标 $Platform, py$PyVer) ..."
# --only-binary :all: 配合 --platform 实现跨平台（在 Windows 上下 Linux 包）
pip download -r $ReqFile -d $OutDir --only-binary=:all: `
    --platform $Platform --python-version $PyVer --implementation cp
if ($LASTEXITCODE -ne 0) {
    Write-Host "!! 部分包没有匹配 wheel，下面再补源码包" -ForegroundColor Yellow
}

Write-Host ">> 补充下载源码包 (sdist) ..."
pip download -r $ReqFile -d $OutDir --no-binary=:all: --no-deps
# sdist 下载失败不影响（多数包已有 wheel）

Write-Host ">> 打包为 pip-packages.tar.gz ..."
# Windows 10/11 自带 tar.exe
tar -czf pip-packages.tar.gz $OutDir

$count = (Get-ChildItem $OutDir).Count
Write-Host ""
Write-Host ">> 完成: pip-packages.tar.gz (共 $count 个文件)"
Write-Host ">> 下一步: 把 pip-packages.tar.gz 传到离线服务器的 /root/BYX/"
