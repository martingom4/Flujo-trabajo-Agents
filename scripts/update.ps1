# Trae la última versión del repo y re-alinea esta máquina (Windows).
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root
if (git remote get-url origin 2>$null) { git pull --ff-only }
& (Join-Path $Root "scripts\install.ps1") @args
