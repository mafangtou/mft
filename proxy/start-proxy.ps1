param(
  [string]$ConfigFile = (Join-Path $PSScriptRoot "env.local.ps1")
)

$ErrorActionPreference = "Stop"

function Write-Log {
  param([string]$Message)
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  Write-Host "[$timestamp] $Message"
}

function Get-LanIp {
  $candidate = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
      $_.IPAddress -notlike "127.*" -and
      $_.IPAddress -notlike "169.254.*" -and
      $_.PrefixOrigin -ne "WellKnown"
    } |
    Sort-Object InterfaceMetric, InterfaceIndex |
    Select-Object -First 1

  if (-not $candidate) {
    throw "Unable to detect a LAN IPv4 address. Set `$BindIp in env.local.ps1."
  }

  return $candidate.IPAddress
}

function Resolve-NginxExe {
  param([string]$ConfiguredPath)

  $candidates = @()
  if ($ConfiguredPath) { $candidates += $ConfiguredPath }
  $candidates += (Join-Path $PSScriptRoot "tools\nginx\nginx.exe")
  $candidates += (Join-Path $PSScriptRoot "nginx\nginx.exe")

  $pathCommand = Get-Command nginx.exe -ErrorAction SilentlyContinue
  if ($pathCommand) { $candidates += $pathCommand.Source }

  foreach ($candidate in $candidates) {
    if ($candidate -and (Test-Path $candidate)) {
      return (Resolve-Path $candidate).Path
    }
  }

  throw "nginx.exe was not found. Install Nginx for Windows and set `$NginxExe in env.local.ps1."
}

function Escape-NginxLiteral {
  param([string]$Value)
  return $Value.Replace("\", "\\").Replace("'", "\'")
}

if (-not (Test-Path $ConfigFile)) {
  $example = Join-Path $PSScriptRoot "env.example"
  throw "Config file not found: $ConfigFile. Copy $example to env.local.ps1 and edit TargetHost/ListenPort."
}

. $ConfigFile

if (-not $TargetScheme) { $TargetScheme = "https" }
if (-not $TargetHost) { throw "TargetHost is required in $ConfigFile." }
if (-not $ListenPort) { $ListenPort = 8080 }
if (-not $RewriteOrigins -or $RewriteOrigins.Count -eq 0) {
  $RewriteOrigins = @("$TargetScheme://$TargetHost")
}
if (-not $BindIp) { $BindIp = Get-LanIp }

$nginxExe = Resolve-NginxExe -ConfiguredPath $NginxExe
$runDir = Join-Path $PSScriptRoot "run"
$logDir = Join-Path $PSScriptRoot "logs"
$configOut = Join-Path $runDir "nginx.conf"
$template = Join-Path $PSScriptRoot "nginx\templates\reverse-proxy.conf.template"
$proxyOrigin = "http://${BindIp}:${ListenPort}"

New-Item -ItemType Directory -Force -Path $runDir, $logDir | Out-Null

$subFilters = foreach ($origin in $RewriteOrigins) {
  if ($origin) {
    "            sub_filter '$(Escape-NginxLiteral $origin)' '$(Escape-NginxLiteral $proxyOrigin)';"
  }
}

$mimeTypesPath = Join-Path (Split-Path $nginxExe -Parent) "conf\mime.types"
if (Test-Path $mimeTypesPath) {
  $mimeTypesBlock = "include       $(($mimeTypesPath -replace '\\', '/'));"
} else {
  $mimeTypesBlock = @"
types {
        text/html                             html htm shtml;
        text/css                              css;
        text/xml                              xml;
        application/javascript                js;
        application/json                      json;
        image/gif                             gif;
        image/jpeg                            jpeg jpg;
        image/png                             png;
        image/svg+xml                         svg svgz;
    }
"@
}

$config = Get-Content $template -Raw
$config = $config.Replace("__BIND_IP__", $BindIp)
$config = $config.Replace("__LISTEN_PORT__", [string]$ListenPort)
$config = $config.Replace("__TARGET_SCHEME__", $TargetScheme)
$config = $config.Replace("__TARGET_HOST__", $TargetHost)
$config = $config.Replace("__RUN_DIR__", ($runDir -replace "\\", "/"))
$config = $config.Replace("__LOG_DIR__", ($logDir -replace "\\", "/"))
$config = $config.Replace("__MIME_TYPES_BLOCK__", $mimeTypesBlock)
$config = $config.Replace("__SUB_FILTER_RULES__", ($subFilters -join [Environment]::NewLine))
Set-Content -Path $configOut -Value $config -Encoding UTF8

Write-Log "Using nginx: $nginxExe"
Write-Log "Generated config: $configOut"
Write-Log "Proxy target: $TargetScheme://$TargetHost"
Write-Log "LAN entrypoint: $proxyOrigin"

& $nginxExe -t -c $configOut -p $PSScriptRoot
if ($LASTEXITCODE -ne 0) { throw "nginx configuration test failed." }

$pidFile = Join-Path $runDir "nginx.pid"
if (Test-Path $pidFile) {
  Write-Log "Reloading existing Nginx instance."
  & $nginxExe -s reload -c $configOut -p $PSScriptRoot
} else {
  Write-Log "Starting Nginx."
  Start-Process -FilePath $nginxExe -ArgumentList @("-c", $configOut, "-p", $PSScriptRoot) -WindowStyle Hidden
}

Start-Sleep -Seconds 1
$healthUrl = "$proxyOrigin/__proxy_health"
$response = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 5
Write-Log "Health check $healthUrl -> HTTP $($response.StatusCode)"
Write-Log "Opening default browser: $proxyOrigin"
Start-Process $proxyOrigin
Write-Log "Access log: $(Join-Path $logDir 'nginx-access.log')"
Write-Log "Error log: $(Join-Path $logDir 'nginx-error.log')"
