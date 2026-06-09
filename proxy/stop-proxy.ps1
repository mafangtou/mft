param(
  [string]$ConfigFile = (Join-Path $PSScriptRoot "run\nginx.conf")
)

$ErrorActionPreference = "Stop"

function Write-Log {
  param([string]$Message)
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  Write-Host "[$timestamp] $Message"
}

function Resolve-NginxExe {
  $candidates = @(
    (Join-Path $PSScriptRoot "tools\nginx\nginx.exe"),
    (Join-Path $PSScriptRoot "nginx\nginx.exe")
  )
  $pathCommand = Get-Command nginx.exe -ErrorAction SilentlyContinue
  if ($pathCommand) { $candidates += $pathCommand.Source }

  foreach ($candidate in $candidates) {
    if ($candidate -and (Test-Path $candidate)) {
      return (Resolve-Path $candidate).Path
    }
  }

  throw "nginx.exe was not found. Stop Nginx manually or add nginx.exe to PATH."
}

$nginxExe = Resolve-NginxExe
if (-not (Test-Path $ConfigFile)) {
  Write-Log "Config file not found: $ConfigFile. Falling back to default stop signal."
  & $nginxExe -s stop -p $PSScriptRoot
} else {
  Write-Log "Stopping Nginx with config: $ConfigFile"
  & $nginxExe -s stop -c $ConfigFile -p $PSScriptRoot
}

Write-Log "Stop signal sent."
