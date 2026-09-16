[CmdletBinding()]
param([string]$GodotPath = $env:GODOT_PATH)
$ErrorActionPreference = 'Stop'
if (-not $GodotPath) {
    $GodotPath = Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw 'Pass -GodotPath C:\path\to\godot.exe or set GODOT_PATH.'
}
$engine = (Resolve-Path -LiteralPath $GodotPath).Path
$output = Join-Path $PSScriptRoot 'exports/windows'
$logDirectory = Join-Path $PSScriptRoot 'artifacts/windows-build'
New-Item -ItemType Directory -Force $output, $logDirectory | Out-Null
$savedAppData = $env:APPDATA
try {
    # Optional project-local template installation; otherwise use Godot's normal profile.
    $localProfile = Join-Path $PSScriptRoot 'exports/windows-tools/profile'
    if (Test-Path -LiteralPath (Join-Path $localProfile 'Godot/export_templates')) {
        $env:APPDATA = $localProfile
    }
    $log = Join-Path $logDirectory 'export.log'
    & $engine --headless --path $PSScriptRoot --editor --import --quit *> $log
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|Parse Error:|^ERROR:(?! Failed to read the root certificate store\.)')) {
        throw "Resource import failed. See $log."
    }
    & $engine --headless --path $PSScriptRoot --export-release 'Windows Desktop' (Join-Path $output 'Hollow Vigil.exe') --quit *>> $log
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|Parse Error:|^ERROR:(?! Failed to read the root certificate store\.)')) {
        throw "Windows export failed. See $log."
    }
    $archive = Join-Path $PSScriptRoot 'exports/Hollow-Vigil-Windows.zip'
    Compress-Archive -LiteralPath (Join-Path $output 'Hollow Vigil.exe') -DestinationPath $archive -Force
    Get-Item (Join-Path $output 'Hollow Vigil.exe'), $archive
} finally {
    $env:APPDATA = $savedAppData
}
