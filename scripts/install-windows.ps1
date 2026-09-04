[CmdletBinding()]
param(
  [string]$ProjectPath = 'C:\steam-work-mcp',
  [string]$RepositoryZip = 'https://github.com/kui-2026/steam-work-mcp/archive/refs/heads/main.zip',
  [int]$Port = 4100
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$projectFullPath = [IO.Path]::GetFullPath($ProjectPath).TrimEnd('\')
$runtimePath = 'C:\steam-work-runtime'
$uvPath = Join-Path $runtimePath 'uv.exe'
$tempRoot = Join-Path $env:TEMP ("steam-work-install-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$zipPath = Join-Path $tempRoot 'source.zip'
$extractPath = Join-Path $tempRoot 'source'

try {
  New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
  New-Item -ItemType Directory -Path $runtimePath -Force | Out-Null

  if (-not (Test-Path -LiteralPath $uvPath -PathType Leaf)) {
    Write-Host '1/5 Installing the private Python runtime...'
    $uvZip = Join-Path $tempRoot 'uv.zip'
    Invoke-WebRequest -Uri 'https://github.com/astral-sh/uv/releases/latest/download/uv-x86_64-pc-windows-msvc.zip' -OutFile $uvZip
    Expand-Archive -LiteralPath $uvZip -DestinationPath $runtimePath -Force
  } else {
    Write-Host '1/5 Python runtime installer already present.'
  }

  Write-Host '2/5 Downloading Steam MCP from GitHub...'
  Invoke-WebRequest -Uri $RepositoryZip -OutFile $zipPath
  Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force
  $appFile = Get-ChildItem -LiteralPath $extractPath -Filter app.py -File -Recurse | Select-Object -First 1
  if (-not $appFile) { throw 'The downloaded repository does not contain app.py.' }
  $releasePath = $appFile.Directory.FullName

  if (Test-Path -LiteralPath $projectFullPath) {
    $existingEnv = Join-Path $projectFullPath '.env'
    if (Test-Path -LiteralPath $existingEnv -PathType Leaf) {
      Copy-Item -LiteralPath $existingEnv -Destination (Join-Path $releasePath '.env') -Force
    }
    Remove-Item -LiteralPath $projectFullPath -Recurse -Force
  }
  Move-Item -LiteralPath $releasePath -Destination $projectFullPath

  $envFile = Join-Path $projectFullPath '.env'
  if (-not (Test-Path -LiteralPath $envFile -PathType Leaf)) {
    $randomBytes = New-Object byte[] 32
    $randomGenerator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
      $randomGenerator.GetBytes($randomBytes)
    } finally {
      $randomGenerator.Dispose()
    }
    $secret = [BitConverter]::ToString($randomBytes).Replace('-', '').ToLowerInvariant()
    @(
      'STEAM_API_KEY='
      'STEAM_USER='
      'MCP_HOST=127.0.0.1'
      "MCP_PORT=$Port"
      "MCP_PATH=/steam-$secret/mcp"
    ) | Set-Content -LiteralPath $envFile -Encoding UTF8
  }

  Write-Host '3/5 Creating an isolated Python environment...'
  & $uvPath venv (Join-Path $projectFullPath '.venv') --python 3.12
  if ($LASTEXITCODE -ne 0) { throw "uv venv failed with exit code $LASTEXITCODE." }

  Write-Host '4/5 Installing the pinned Steam MCP package...'
  & $uvPath pip install --python (Join-Path $projectFullPath '.venv\Scripts\python.exe') -r (Join-Path $projectFullPath 'requirements.txt')
  if ($LASTEXITCODE -ne 0) { throw "Dependency installation failed with exit code $LASTEXITCODE." }

  Write-Host '5/5 Starting and verifying Steam MCP...'
  & (Join-Path $projectFullPath 'scripts\start-windows.ps1') -ProjectPath $projectFullPath -Port $Port
  if ($LASTEXITCODE -ne 0) { throw "Steam MCP start failed with exit code $LASTEXITCODE." }

  $mcpPathLine = Get-Content -LiteralPath $envFile | Where-Object { $_ -like 'MCP_PATH=*' } | Select-Object -First 1
  Write-Host ''
  Write-Host 'Steam MCP installation succeeded.' -ForegroundColor Green
  Write-Host "Local endpoint: http://127.0.0.1:$Port/$($mcpPathLine.Substring(9).TrimStart('/'))"
  Write-Host 'Personal Steam access is not enabled until STEAM_API_KEY and STEAM_USER are added locally.'
} finally {
  if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}
