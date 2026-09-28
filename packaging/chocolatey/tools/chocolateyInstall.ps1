$ErrorActionPreference = 'Stop'
$tools = Split-Path -Parent $MyInvocation.MyCommand.Definition
Install-BinFile -Name 'elele-dns' -Path (Join-Path $tools 'elele-dns.ps1')
