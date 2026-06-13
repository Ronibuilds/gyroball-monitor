# Publishes a self-contained, single-file Gyroball.exe and zips it
# (mirrors the macOS release.sh, which builds the .app and a DMG).
#
# Usage:  pwsh ./release.ps1 [-Runtime win-x64]
param(
    [string]$Runtime = "win-x64",
    [string]$Configuration = "Release"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$proj = "$root/src/Gyroball/Gyroball.csproj"
$outDir = "$root/dist/$Runtime"

Write-Host "Running tests…" -ForegroundColor Cyan
dotnet test "$root/tests/Gyroball.Tests/Gyroball.Tests.csproj" -c $Configuration

Write-Host "Publishing self-contained single-file exe ($Runtime)…" -ForegroundColor Cyan
if (Test-Path $outDir) { Remove-Item -Recurse -Force $outDir }
dotnet publish $proj `
    -c $Configuration `
    -r $Runtime `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -o $outDir

$zip = "$root/dist/Gyroball-$Runtime.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path "$outDir/*" -DestinationPath $zip

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "  Exe:  $outDir/Gyroball.exe"
Write-Host "  Zip:  $zip"
