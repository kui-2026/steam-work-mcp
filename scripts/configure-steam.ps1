[CmdletBinding()]
param([string]$ProjectPath = 'C:\steam-work-mcp')

$ErrorActionPreference = 'Stop'
$projectFullPath = [IO.Path]::GetFullPath($ProjectPath).TrimEnd('\')
$envFile = Join-Path $projectFullPath '.env'
$tunnelExe = 'C:\tunnel-client\tunnel-client.exe'

if (-not (Test-Path -LiteralPath $envFile -PathType Leaf)) {
  throw "Configuration file not found: $envFile"
}
if (-not (Test-Path -LiteralPath $tunnelExe -PathType Leaf)) {
  throw "Tunnel client not found: $tunnelExe"
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

# Restart the HTTP service if it is currently used.
$listener = Get-NetTCPConnection -LocalPort 4100 -State Listen -ErrorAction SilentlyContinue
foreach ($item in @($listener)) {
  $proc = Get-Process -Id $item.OwningProcess -ErrorAction SilentlyContinue
  if ($proc -and $proc.ProcessName -in @('python', 'pythonw')) {
    Stop-Process -Id $proc.Id -Force
  }
}

# Restart only the Steam tunnel so its child process reloads .env.
Get-CimInstance Win32_Process -Filter "Name='tunnel-client.exe'" |
  Where-Object { $_.CommandLine -match 'run\s+--profile\s+steam' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

Start-Process `
  -FilePath $tunnelExe `
  -ArgumentList @('run', '--profile', 'steam') `
  -WindowStyle Hidden `
  -RedirectStandardOutput 'C:\tunnel-client\steam-tunnel.log' `
  -RedirectStandardError 'C:\tunnel-client\steam-tunnel-error.log'

Write-Host 'Steam account access was saved locally and the Steam tunnel was restarted.' -ForegroundColor Green
