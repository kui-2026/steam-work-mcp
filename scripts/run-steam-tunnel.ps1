[CmdletBinding()]
param(
  [string]$Profile = 'steam',
  [int]$HealthPort = 18083
)

$ErrorActionPreference = 'Stop'
$tunnelDir = 'C:\tunnel-client'
$tunnelExe = Join-Path $tunnelDir 'tunnel-client.exe'
$logFile = Join-Path $tunnelDir 'steam-tunnel.log'
$errorLog = Join-Path $tunnelDir 'steam-tunnel-error.log'

if (-not (Test-Path -LiteralPath $tunnelExe -PathType Leaf)) {
  throw "Tunnel client not found: $tunnelExe"
}

# Task Scheduler may retain an old environment block. Read the registry-backed
# user variable explicitly every time this wrapper starts.
$controlKey = [Environment]::GetEnvironmentVariable('CONTROL_PLANE_API_KEY', 'User')
if ([string]::IsNullOrWhiteSpace($controlKey)) {
  throw 'CONTROL_PLANE_API_KEY is missing from the Windows user environment.'
}
$env:CONTROL_PLANE_API_KEY = $controlKey
$controlKey = $null

$arguments = @(
  'run'
  '--profile'
  $Profile
  '--health.listen-addr'
  "127.0.0.1:$HealthPort"
)

$process = Start-Process `
  -FilePath $tunnelExe `
  -ArgumentList $arguments `
  -WorkingDirectory $tunnelDir `
  -RedirectStandardOutput $logFile `
  -RedirectStandardError $errorLog `
  -PassThru `
  -Wait

exit $process.ExitCode
