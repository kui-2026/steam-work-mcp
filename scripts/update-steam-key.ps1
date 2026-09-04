[CmdletBinding()]
param([string]$ProjectPath = 'C:\steam-work-mcp')

$ErrorActionPreference = 'Stop'
$projectFullPath = [IO.Path]::GetFullPath($ProjectPath).TrimEnd('\')
$envFile = Join-Path $projectFullPath '.env'

if (-not (Test-Path -LiteralPath $envFile -PathType Leaf)) {
  throw "Configuration file not found: $envFile"
}

$keySecure = Read-Host 'Paste your new Steam Web API key (input is hidden)' -AsSecureString
$keyPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($keySecure)
try {
  $apiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($keyPtr)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($keyPtr)
}

if ($apiKey -notmatch '^[A-Fa-f0-9]{32}$') {
  throw 'The Steam API key must contain exactly 32 hexadecimal characters.'
}

$lines = @(Get-Content -LiteralPath $envFile)
$found = $false
$updated = $lines | ForEach-Object {
  if ($_ -like 'STEAM_API_KEY=*') {
    $found = $true
    "STEAM_API_KEY=$apiKey"
  } else {
    $_
  }
}
if (-not $found) {
  $updated += "STEAM_API_KEY=$apiKey"
}
$updated | Set-Content -LiteralPath $envFile -Encoding UTF8
$apiKey = $null
$keySecure = $null

$repairScript = Join-Path $projectFullPath 'scripts\repair-steam-channel.ps1'
if (-not (Test-Path -LiteralPath $repairScript -PathType Leaf)) {
  throw "Steam channel repair script not found: $repairScript"
}

& $repairScript -ProjectPath $projectFullPath -Profile steam -HealthPort 18083
Write-Host 'Steam API key updated; the existing Steam profile URL was preserved.' -ForegroundColor Green
