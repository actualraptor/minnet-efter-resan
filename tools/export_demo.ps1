# Exports the Windows demo, zips it, unpacks the zip into a clean temp folder and
# boots it headless for a few seconds (the "runs without the editor" check).
#   powershell -File tools/export_demo.ps1 [-Godot <path to godot console exe>]
param(
	[string]$Godot = "D:\Spel\GODOT\Godot_v4.7.2-stable_win64_console.exe"
)
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $repo "build\demo"
$zip = Join-Path $repo "build\MinnetEfterResan_Demo1_win64.zip"
New-Item -ItemType Directory -Force $outDir | Out-Null
Remove-Item (Join-Path $outDir "*") -Recurse -Force -ErrorAction SilentlyContinue

& $Godot --headless --path (Join-Path $repo "game") --import | Out-Null
& $Godot --headless --path (Join-Path $repo "game") --export-release "Windows Desktop" (Join-Path $outDir "MinnetEfterResan.exe")
if (-not (Test-Path (Join-Path $outDir "MinnetEfterResan.exe"))) { throw "export failed" }

Remove-Item $zip -Force -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $outDir "*") -DestinationPath $zip
$mb = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Write-Host "zip: $zip ($mb MB)"

$clean = Join-Path $env:TEMP ("minnet_demo_" + [guid]::NewGuid().ToString("N"))
Expand-Archive -Path $zip -DestinationPath $clean
$p = Start-Process -FilePath (Join-Path $clean "MinnetEfterResan.exe") -ArgumentList "--headless", "--quit-after", "600" -PassThru -Wait -WorkingDirectory $clean
Write-Host "clean-folder boot exit code: $($p.ExitCode)"
Remove-Item $clean -Recurse -Force
if ($p.ExitCode -ne 0) { throw "the packaged build did not boot cleanly" }
Write-Host "OK"
