# Debug build + launch (mirrors the macOS run.sh).
# Usage:  pwsh ./run.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Building Gyroball (Debug)…" -ForegroundColor Cyan
dotnet build "$root/src/Gyroball/Gyroball.csproj" -c Debug

Write-Host "Launching…" -ForegroundColor Cyan
dotnet run --project "$root/src/Gyroball/Gyroball.csproj" -c Debug
