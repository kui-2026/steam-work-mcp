[CmdletBinding()]
param(
  [string]$ProjectPath = 'C:\steam-work-mcp',
  [int]$Port = 4100
)

$ErrorActionPreference = 'Stop'
$projectFullPath = [IO.Path]::GetFullPath($ProjectPath).TrimEnd('\')
$pythonPath = Join-Path $projectFullPath '.venv\Scripts\python.exe'
$appPath = Join-Path $projectFullPath 'app.py'

if (-not (Test-Path -LiteralPath $pythonPath -PathType Leaf)) {
  throw "Python environment not found: $pythonPath"
}
if (-not (Test-Path -LiteralPath (Join-Path $projectFullPath '.env') -PathType Leaf)) {
  throw "Configuration file not found: $projectFullPath\.env"
}

$listeners = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
foreach ($listener in $listeners) {
  $process = Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue
  if ($process -and $process.ProcessName -in @('python', 'pythonw')) {
    Stop-Process -Id $process.Id -Force
    Wait-Process -Id $process.Id -Timeout 10 -ErrorAction SilentlyContinue
  } elseif ($process) {
    throw "Port $Port is used by $($process.ProcessName); refusing to stop it."
  }
}

Start-Process -FilePath $pythonPath `
  -ArgumentList $appPath `
  -WorkingDirectory $projectFullPath `
  -WindowStyle Hidden `
  -RedirectStandardOutput (Join-Path $projectFullPath 'mcp.log') `
  -RedirectStandardError (Join-Path $projectFullPath 'mcp-error.log')

for ($attempt = 0; $attempt -lt 30; $attempt += 1) {
  Start-Sleep -Milliseconds 500
  $listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
  if ($listener) {
    Write-Host "Steam MCP is listening on 127.0.0.1:$Port" -ForegroundColor Green
    exit 0
  }
}

$errorLog = Join-Path $projectFullPath 'mcp-error.log'
$details = if (Test-Path -LiteralPath $errorLog) {
  (Get-Content -LiteralPath $errorLog -Tail 30 -ErrorAction SilentlyContinue) -join [Environment]::NewLine
} else {
  'No error log was created.'
}
throw "Steam MCP did not start.`n$details"
