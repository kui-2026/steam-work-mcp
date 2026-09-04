[CmdletBinding()]
param([string]$ProjectPath = 'C:\steam-work-mcp')

$ErrorActionPreference = 'Stop'
$projectFullPath = [IO.Path]::GetFullPath($ProjectPath).TrimEnd('\')
$envFile = Join-Path $projectFullPath '.env'

if (-not (Test-Path -LiteralPath $envFile -PathType Leaf)) {
  throw "Configuration file not found: $envFile"
}

$keySecure = Read-Host 'Paste your Steam Web API key here (it stays on the VPS)' -AsSecureString
$keyPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($keySecure)
try {
  $apiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($keyPtr)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($keyPtr)
}
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
$keySecure = $null

$repairScript = Join-Path $projectFullPath 'scripts\repair-steam-channel.ps1'
if (-not (Test-Path -LiteralPath $repairScript -PathType Leaf)) {
  throw "Steam channel repair script not found: $repairScript"
}

& $repairScript -ProjectPath $projectFullPath -Profile steam -HealthPort 18083
Write-Host 'Steam account access was saved locally and the Steam channel is ready.' -ForegroundColor Green
