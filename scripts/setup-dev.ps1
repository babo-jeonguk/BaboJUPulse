$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

git config core.hooksPath .githooks
dotnet restore BaboJUPulse.slnx

Write-Host "Development setup complete. Hooks: .githooks; solution restored."
