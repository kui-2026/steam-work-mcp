[CmdletBinding()]
param(
  [string]$ProjectPath = 'C:\steam-work-mcp',
  [string]$Profile = 'steam',
  [int]$HealthPort = 18083,
  [string]$TaskName = 'SteamTunnelClient'
)

$ErrorActionPreference = 'Stop'
$projectFullPath = [IO.Path]::GetFullPath($ProjectPath).TrimEnd('\')
$tunnelDir = 'C:\tunnel-client'
$tunnelExe = Join-Path $tunnelDir 'tunnel-client.exe'
$profileFile = Join-Path ([Environment]::GetFolderPath('ApplicationData')) "tunnel-client\$Profile.yaml"
$readyUrl = "http://127.0.0.1:$HealthPort/readyz"

if (-not (Test-Path -LiteralPath $tunnelExe -PathType Leaf)) {
  throw "Tunnel client not found: $tunnelExe"
}
if (-not (Test-Path -LiteralPath $profileFile -PathType Leaf)) {
  throw "Tunnel profile not found: $profileFile"
}
if (-not (Test-Path -LiteralPath (Join-Path $projectFullPath '.env') -PathType Leaf)) {
  throw "Steam MCP configuration not found: $projectFullPath\.env"
}

# Scheduled tasks do not inherit variables that only exist in an open shell.
$controlKey = [Environment]::GetEnvironmentVariable('CONTROL_PLANE_API_KEY', 'User')
if ([string]::IsNullOrWhiteSpace($controlKey)) {
  $controlKey = [Environment]::GetEnvironmentVariable('CONTROL_PLANE_API_KEY', 'Process')
  if ([string]::IsNullOrWhiteSpace($controlKey)) {
    throw 'CONTROL_PLANE_API_KEY is not available in the current process or user environment.'
  }
  [Environment]::SetEnvironmentVariable('CONTROL_PLANE_API_KEY', $controlKey, 'User')
}
$env:CONTROL_PLANE_API_KEY = $controlKey
$controlKey = $null

# If this profile forwards to the HTTP service, make sure only that service is up.
$profileText = Get-Content -LiteralPath $profileFile -Raw
if ($profileText -match '127\.0\.0\.1:4100|localhost:4100') {
  & (Join-Path $projectFullPath 'scripts\start-windows.ps1') -ProjectPath $projectFullPath -Port 4100
}
$profileText = $null

# Stop only the Steam tunnel. Never stop tunnel-client processes by name alone.
$profilePattern = 'run\s+--profile(?:=|\s+)' + [Regex]::Escape($Profile) + '(?:\s|$)'
Get-CimInstance Win32_Process -Filter "Name='tunnel-client.exe'" |
  Where-Object { $_.CommandLine -match $profilePattern } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

$arguments = "run --profile $Profile --health.listen-addr 127.0.0.1:$HealthPort"
$action = New-ScheduledTaskAction `
  -Execute $tunnelExe `
  -Argument $arguments `
  -WorkingDirectory $tunnelDir
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet `
  -StartWhenAvailable `
  -RestartCount 10 `
  -RestartInterval (New-TimeSpan -Minutes 1) `
  -ExecutionTimeLimit (New-TimeSpan -Days 3650)

Register-ScheduledTask `
  -TaskName $TaskName `
  -Action $action `
  -Trigger $trigger `
  -Settings $settings `
  -Description 'Persistent Steam MCP tunnel on health port 18083' `
  -Force | Out-Null

Start-ScheduledTask -TaskName $TaskName

$lastError = $null
for ($attempt = 0; $attempt -lt 30; $attempt += 1) {
  Start-Sleep -Seconds 1
  try {
    $response = Invoke-WebRequest -Uri $readyUrl -UseBasicParsing -TimeoutSec 3
    if ($response.StatusCode -eq 200) {
      Write-Host 'Steam MCP channel is ready.' -ForegroundColor Green
      Write-Host "Ready check: $readyUrl -> 200"
      exit 0
    }
  } catch {
    $lastError = $_.Exception.Message
  }
}

$taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
$state = if ($task) { $task.State } else { 'missing' }
$lastResult = if ($taskInfo) { $taskInfo.LastTaskResult } else { 'unknown' }
throw "Steam tunnel did not become ready. TaskState=$state; LastTaskResult=$lastResult; ReadyError=$lastError"
