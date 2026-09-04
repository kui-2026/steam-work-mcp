[CmdletBinding()]
param([string]$ProjectPath = 'C:\steam-work-mcp')

$ErrorActionPreference = 'Stop'
$projectFullPath = [IO.Path]::GetFullPath($ProjectPath).TrimEnd('\')
$envFile = Join-Path $projectFullPath '.env'
if (-not (Test-Path -LiteralPath $envFile -PathType Leaf)) {
  throw "Configuration file not found: $envFile"
}

$apiKey = Read-Host 'Paste your 32-character Steam Web API key here (it stays on the VPS)'
if ($apiKey -notmatch '^[A-Fa-f0-9]{32}$') {
  throw 'The Steam API key must contain exactly 32 hexadecimal characters.'
}
$steamUser = Read-Host 'Enter your Steam profile URL, vanity name, or 17-digit SteamID64'
if ([string]::IsNullOrWhiteSpace($steamUser)) {
  throw 'Steam user cannot be empty.'
}

$lines = @(Get-Content -LiteralPath $envFile)
$lines = $lines | ForEach-Object {
  if ($_ -like 'STEAM_API_KEY=*') { "STEAM_API_KEY=$apiKey" }
  elseif ($_ -like 'STEAM_USER=*') { "STEAM_USER=$steamUser" }
  else { $_ }
}
$lines | Set-Content -LiteralPath $envFile -Encoding UTF8
$apiKey = $null

& (Join-Path $projectFullPath 'scripts\start-windows.ps1') -ProjectPath $projectFullPath -Port 4100
Write-Host 'Steam account access configured and the MCP service restarted.' -ForegroundColor Green
