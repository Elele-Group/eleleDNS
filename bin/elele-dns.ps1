[CmdletBinding()]
param(
  [Parameter(Position = 0)] [string]$Command = "menu",
  [string]$Dir = $(if ($env:ELELE_DIR) { $env:ELELE_DIR } else { Join-Path $HOME "elele-dns" }),
  [int]$Port = $(if ($env:ELELE_PORT) { [int]$env:ELELE_PORT } else { 3000 }),
  [switch]$Plain,
  [switch]$Help,
  [Alias("V", "version")] [switch]$VersionFlag
)

$ErrorActionPreference = "Stop"
$Version = "0.2.0"
$HealthUrl = "http://127.0.0.1:$Port/api/health"
$Ansi = -not $Plain -and $Host.UI.SupportsVirtualTerminal
$Cyan = if ($Ansi) { "`e[38;5;81m" } else { "" }
$Green = if ($Ansi) { "`e[38;5;114m" } else { "" }
$Amber = if ($Ansi) { "`e[38;5;214m" } else { "" }
$Grey = if ($Ansi) { "`e[38;5;245m" } else { "" }
$Bold = if ($Ansi) { "`e[1m" } else { "" }
$Dim = if ($Ansi) { "`e[2m" } else { "" }
$Reset = if ($Ansi) { "`e[0m" } else { "" }

function Write-Banner {
  Write-Host ""
  Write-Host "  ${Bold}${Cyan}ELELE${Reset}${Cyan}.${Reset}${Bold} DNS${Reset}"
  Write-Host "  ${Grey}private resolver control, from your terminal${Reset}"
  Write-Host "  ${Dim}v$Version${Reset}"
  Write-Host ""
}
function Fail([string]$Message) { throw $Message }
function Resolve-Compose {
  if (-not (Test-Path (Join-Path $Dir "docker-compose.yml"))) { Fail "No Docker project found at $Dir. Use -Dir or run the installer first." }
  if (Get-Command docker -ErrorAction SilentlyContinue) {
    try { docker compose version *> $null; if ($LASTEXITCODE -eq 0) { return @("docker", "compose") } } catch {}
  }
  if (Get-Command docker-compose -ErrorAction SilentlyContinue) { return @("docker-compose") }
  Fail "Docker Compose is not installed."
}
function Invoke-Compose([string[]]$Args) {
  $compose = Resolve-Compose
  Push-Location $Dir
  try {
    if ($compose.Count -eq 1) { & $compose[0] $Args }
    else { & $compose[0] $compose[1] $Args }
  } finally { Pop-Location }
}
function Invoke-Animated([string]$Label, [scriptblock]$Action) {
  if (-not $Ansi) { & $Action; return }
  $frames = @("⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏")
  for ($i = 0; $i -lt $frames.Count; $i++) {
    Write-Host -NoNewline "`r  $Cyan$($frames[$i])$Reset $Label"
    Start-Sleep -Milliseconds 45
  }
  & $Action
  $exitCode = $LASTEXITCODE
  Write-Host "`r$([char]27)[K"
  if ($exitCode -ne 0) { Fail "$Label failed" }
  Write-Host "  ${Green}✓${Reset} $Label"
}
function Show-Status {
  $null = Resolve-Compose
  Write-Host "  ${Bold}ELELE DNS STATUS${Reset}"
  Invoke-Compose @("ps")
  try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 $HealthUrl *> $null; Write-Host "  ${Green}✓${Reset} dashboard healthy at $HealthUrl" } catch { Write-Host "  ${Amber}!${Reset} dashboard is not answering at $HealthUrl" }
}
function Show-Doctor {
  Write-Host "  ${Bold}ELELE DNS DOCTOR${Reset}"
  if (Get-Command docker -ErrorAction SilentlyContinue) { Write-Host "  ${Green}✓${Reset} docker command found" } else { Write-Host "  ${Amber}!${Reset} docker command missing" }
  try { docker info *> $null; Write-Host "  ${Green}✓${Reset} docker engine reachable" } catch { Write-Host "  ${Amber}!${Reset} docker engine is not reachable" }
  $null = Resolve-Compose
  Write-Host "  ${Green}✓${Reset} compose project found at $Dir"
  try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 $HealthUrl *> $null; Write-Host "  ${Green}✓${Reset} health endpoint answered" } catch { Write-Host "  ${Amber}!${Reset} health endpoint did not answer" }
}
function Show-Config { $null = Resolve-Compose; Write-Host "  project: $Dir"; Write-Host "  compose: $(Join-Path $Dir 'docker-compose.yml')"; Write-Host "  env:     $(Join-Path $Dir '.env')"; Write-Host "  url:     $HealthUrl" }
function Show-Menu {
  Write-Banner
  if (-not [Environment]::UserInteractive) { Show-Status; return }
  while ($true) {
    Write-Host "  ${Cyan}${Bold}1${Reset} status     ${Cyan}${Bold}2${Reset} start      ${Cyan}${Bold}3${Reset} restart"
    Write-Host "  ${Cyan}${Bold}4${Reset} logs       ${Cyan}${Bold}5${Reset} update     ${Cyan}${Bold}6${Reset} doctor"
    Write-Host "  ${Cyan}${Bold}q${Reset} quit"
    $choice = Read-Host "  choose a command"
    switch ($choice.ToLowerInvariant()) {
      "1" { Show-Status }
      "2" { Invoke-Animated "starting dashboard" { Invoke-Compose @("up", "-d") }; Show-Status }
      "3" { Invoke-Animated "restarting dashboard" { Invoke-Compose @("up", "-d", "--force-recreate") }; Show-Status }
      "4" { Invoke-Compose @("logs", "-f", "--tail=120") }
      "5" { Invoke-Animated "pulling latest image" { Invoke-Compose @("pull") }; Invoke-Animated "restarting dashboard" { Invoke-Compose @("up", "-d") } }
      "6" { Show-Doctor }
      "q" { return }
      default { Write-Host "  ${Amber}!${Reset} choose 1 through 6" }
    }
  }
}

if ($Help -or $Command -in @("help", "-h", "--help")) {
  Write-Host "elele-dns v$Version"
  Write-Host "Usage: elele-dns [status|start|stop|restart|logs|update|doctor|config|menu] [-Dir PATH] [-Port PORT]"
  exit 0
}
if ($VersionFlag -or $Command -in @("version", "-V", "--version")) {
  Write-Host $Version
  exit 0
}
Write-Banner
switch ($Command.ToLowerInvariant()) {
  "status" { Show-Status }
  "start" { Invoke-Animated "starting dashboard" { Invoke-Compose @("up", "-d") }; Show-Status }
  "stop" { Invoke-Animated "stopping dashboard" { Invoke-Compose @("down") } }
  "restart" { Invoke-Animated "restarting dashboard" { Invoke-Compose @("up", "-d", "--force-recreate") }; Show-Status }
  "logs" { Invoke-Compose @("logs", "-f", "--tail=120") }
  "update" { Invoke-Animated "pulling latest image" { Invoke-Compose @("pull") }; Invoke-Animated "restarting dashboard" { Invoke-Compose @("up", "-d") } }
  "doctor" { Show-Doctor }
  "config" { Show-Config }
  "menu" { Show-Menu }
  default { Fail "Unknown command '$Command'. Use -Help." }
}
