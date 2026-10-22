# Instala el flujo global de Claude Code en %USERPROFILE%\.claude (Windows nativo).
# Uso:  powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 [-NoTools]
# Requisitos: Python 3 y Git for Windows (Claude Code corre los hooks .sh con Git Bash).
param([switch]$NoTools)
$ErrorActionPreference = "Stop"

$Root   = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Src    = Join-Path $Root "plugins\flujo-martin"
$Dest   = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE ".claude" }
$Backup = Join-Path $Dest ("backups\flujo-trabajo-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
$Py = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $Py) { $Py = Get-Command python -ErrorAction SilentlyContinue }
if (-not $Py) { throw "Hace falta Python 3 (winget install Python.Python.3.12)" }

function Install-Item($item, $sub) {
  $target = Join-Path $Dest $sub
  New-Item -ItemType Directory -Force -Path $target | Out-Null
  $existing = Join-Path $target $item.Name
  if (Test-Path $existing) {
    New-Item -ItemType Directory -Force -Path (Join-Path $Backup $sub) | Out-Null
    Copy-Item $existing (Join-Path $Backup $sub) -Recurse -Force
    Remove-Item $existing -Recurse -Force
  }
  Copy-Item $item.FullName $target -Recurse -Force
}
Write-Host "==> Destino: $Dest"
Get-ChildItem (Join-Path $Src "skills") -Directory | ForEach-Object { Install-Item $_ "skills" }
Get-ChildItem (Join-Path $Src "agents") -Filter *.md | ForEach-Object { Install-Item $_ "agents" }
Get-ChildItem (Join-Path $Src "hooks") -Filter *.sh | ForEach-Object { Install-Item $_ "hooks" }
Write-Host "==> Skills, agente y hooks copiados."
if (Test-Path $Backup) { Write-Host "    respaldo de lo reemplazado: $Backup" }

& $Py.Source (Join-Path $Root "scripts\merge.py") (Join-Path $Root "claude-code") $Dest
if ($NoTools) { Write-Host "==> Listo (sin herramientas externas)."; exit 0 }

Write-Host "==> graphify"
$env:Path = "$env:USERPROFILE\.local\bin;$env:Path"
if (-not (Get-Command graphify -ErrorAction SilentlyContinue)) {
  if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
  }
  uv tool install graphifyy
}
if (Get-Command graphify -ErrorAction SilentlyContinue) { graphify install }
else { Write-Host "    AVISO: 'uv tool update-shell', abrí otra terminal y corré 'graphify install'." }

Write-Host "==> ponytail"
if (Get-Command claude -ErrorAction SilentlyContinue) {
  claude plugin marketplace add DietrichGebert/ponytail
  claude plugin install ponytail@ponytail
} else {
  Write-Host "    En Claude Code, en DOS mensajes: /plugin marketplace add DietrichGebert/ponytail  y  /plugin install ponytail@ponytail"
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Write-Host "    AVISO: ponytail necesita Node.js." }
Write-Host "==> Listo. Abrí una sesión nueva y verificá (PASO-A-PASO.md, paso 5)."
