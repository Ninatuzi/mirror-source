# Windows PowerShell 版：下载 npm 依赖（含全部传递依赖）并打包（不需要 bash）
# 在【联网的 Windows 机器】上运行。需要已安装 Node + npm。
#
# 用法（在 PowerShell 里，进入 online-machine 目录后）:
#   powershell -ExecutionPolicy Bypass -File .\download-npm.ps1
#
# 原理：用清单生成 package.json -> npm 解析出完整依赖树写入 package-lock.json
#       -> 从 lock 文件提取所有 .tgz 地址逐个下载。

param(
    [string]$ListFile = "..\common-packages\npm-common.txt"
)

$WorkDir = "npm-build"
$OutDir  = "npm-packages"

Remove-Item -Recurse -Force $WorkDir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
New-Item -ItemType Directory -Force -Path $OutDir  | Out-Null

Write-Host ">> 生成临时 package.json ..."
Push-Location $WorkDir
npm init -y | Out-Null
Pop-Location

# 读取清单，忽略注释(#)和空行
$pkgs = Get-Content $ListFile | ForEach-Object { ($_ -replace '#.*', '').Trim() } |
        Where-Object { $_ -ne '' }

Write-Host ">> 解析依赖树（只生成 lock，不真正安装）: $($pkgs.Count) 个直接依赖 ..."
Push-Location $WorkDir
npm install --package-lock-only --save @pkgs
Pop-Location

Write-Host ">> 从 package-lock.json 提取 tarball 地址 ..."
$lockPath = Join-Path $WorkDir "package-lock.json"
$lock = Get-Content $lockPath -Raw | ConvertFrom-Json

$urls = @()
foreach ($prop in $lock.packages.PSObject.Properties) {
    $resolved = $prop.Value.resolved
    if ($resolved -and $resolved -like "*.tgz") { $urls += $resolved }
}
$urls = $urls | Sort-Object -Unique

Write-Host ">> 共 $($urls.Count) 个 tarball，开始下载 ..."
foreach ($url in $urls) {
    $fname = Split-Path $url -Leaf
    $dest  = Join-Path $OutDir $fname
    if (-not (Test-Path $dest)) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
            Write-Host "   ok: $fname"
        } catch {
            Write-Host "   FAIL: $url" -ForegroundColor Red
        }
    }
}

Write-Host ">> 打包为 npm-packages.tar.gz ..."
tar -czf npm-packages.tar.gz $OutDir

$count = (Get-ChildItem $OutDir).Count
Write-Host ""
Write-Host ">> 完成: npm-packages.tar.gz (共 $count 个 tgz)"
Write-Host ">> 下一步: 把 npm-packages.tar.gz 传到离线服务器的 /root/BYX/"
