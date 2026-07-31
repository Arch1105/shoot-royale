# Exports Shoot Royale to a Windows .exe and copies the NVDA helper's loose
# files next to it - NvdaSpeak.exe/nvdaControllerClient64.dll are real native
# binaries, not Godot resources, so they can't live inside the exported
# build's embedded .pck (see Voice.gd's _resolve_nvda_helper_path comment).
# Run: powershell -File tools/build_export.ps1

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$godot = Join-Path $root "tools\godot\Godot_v4.7.1-stable_win64_console.exe"
$outputExe = "C:\Users\user\Downloads\Shoot Royale.exe"

& $godot --headless --path $root --export-release "Windows Desktop" $outputExe
if ($LASTEXITCODE -ne 0) {
    throw "Godot export failed with exit code $LASTEXITCODE"
}

$outputDir = Split-Path $outputExe -Parent
$binDest = Join-Path $outputDir "bin"
New-Item -ItemType Directory -Force -Path $binDest | Out-Null
Copy-Item (Join-Path $root "bin\NvdaSpeak.exe") $binDest -Force
Copy-Item (Join-Path $root "bin\nvdaControllerClient64.dll") $binDest -Force

Write-Host "Exported to $outputExe with bin/ alongside it."
