# Windows PowerShell version: download npm dependencies (incl. all transitive deps)
# and package them (no bash needed). Run on the ONLINE Windows machine.
# Requires Node + npm installed.
#
# Usage (in PowerShell, inside the online-machine folder):
#   Set-ExecutionPolicy -Scope Process Bypass
#   .\download-npm.ps1
#
# How it works: generate a package.json from the list -> npm resolves the full
# dependency tree into package-lock.json -> extract every .tgz URL and download.

param(
    [string]$ListFile = "..\common-packages\npm-common.txt"
)

$WorkDir = "npm-build"
$OutDir  = "npm-packages"

Remove-Item -Recurse -Force $WorkDir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
New-Item -ItemType Directory -Force -Path $OutDir  | Out-Null

Write-Host ">> Generating temporary package.json ..."
Push-Location $WorkDir
npm init -y | Out-Null
Pop-Location

# Read the package list, ignore comments (#) and blank lines
$pkgs = Get-Content $ListFile | ForEach-Object { ($_ -replace '#.*', '').Trim() } |
        Where-Object { $_ -ne '' }

Write-Host ">> Resolving dependency tree (lock only, no real install): $($pkgs.Count) direct deps ..."
Push-Location $WorkDir
npm install --package-lock-only --save @pkgs
Pop-Location

Write-Host ">> Extracting tarball URLs from package-lock.json ..."
$lockPath = Join-Path $WorkDir "package-lock.json"
$lock = Get-Content $lockPath -Raw | ConvertFrom-Json

$urls = @()
foreach ($prop in $lock.packages.PSObject.Properties) {
    $resolved = $prop.Value.resolved
    if ($resolved -and $resolved -like "*.tgz") { $urls += $resolved }
}
$urls = $urls | Sort-Object -Unique

Write-Host ">> $($urls.Count) tarballs to download ..."
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

Write-Host ">> Packing into npm-packages.tar.gz ..."
tar -czf npm-packages.tar.gz $OutDir

$count = (Get-ChildItem $OutDir).Count
Write-Host ""
Write-Host ">> Done: npm-packages.tar.gz ($count tgz files)"
Write-Host ">> Next: copy npm-packages.tar.gz to the offline server /root/BYX/"
