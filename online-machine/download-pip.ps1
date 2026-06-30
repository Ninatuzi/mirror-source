# Windows PowerShell version: download pip dependencies and package them (no bash needed).
# Run on the ONLINE Windows machine. Requires a working Python + pip.
#
# IMPORTANT: if you use a venv (e.g. conda/virtualenv), ACTIVATE it first so the
# correct pip is used. A broken global pip will cause ModuleNotFoundError.
#
# Usage (in PowerShell, inside the online-machine folder):
#   Set-ExecutionPolicy -Scope Process Bypass
#   .\download-pip.ps1
#
# Default target: Python 3.13 + x86_64 Linux (matches the offline server).

param(
    [string]$ReqFile  = "..\common-packages\pip-common.txt",
    [string]$PyVer    = "313",
    [string]$Platform = "manylinux2014_x86_64"
)

$OutDir = "pip-packages"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Write-Host ">> Downloading binary wheels (target $Platform, py$PyVer) ..."
# --only-binary :all: together with --platform enables cross-platform download
# (download Linux packages while running on Windows).
pip download -r $ReqFile -d $OutDir --only-binary=:all: `
    --platform $Platform --python-version $PyVer --implementation cp

if ($LASTEXITCODE -ne 0) {
    # Only needed if some package had no matching wheel. For well-supported
    # targets (py3.13 + manylinux x86_64) this branch is usually skipped.
    Write-Host "!! Some packages had no wheel; trying sdist fallback ..." -ForegroundColor Yellow
    pip download -r $ReqFile -d $OutDir --no-binary=:all: --no-deps
} else {
    Write-Host ">> All wheels downloaded; sdist fallback not needed."
}

Write-Host ">> Packing into pip-packages.tar.gz ..."
# Windows 10/11 ships tar.exe
tar -czf pip-packages.tar.gz $OutDir

$count = (Get-ChildItem $OutDir).Count
Write-Host ""
Write-Host ">> Done: pip-packages.tar.gz ($count files in $OutDir)"
Write-Host ">> Next: copy pip-packages.tar.gz to the offline server /root/BYX/"
