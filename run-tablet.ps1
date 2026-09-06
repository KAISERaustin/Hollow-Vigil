[CmdletBinding()]
param(
    [string]$Device,
    [string]$GodotPath = "$env:USERPROFILE\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
)
$ErrorActionPreference = 'Stop'
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path $adb)) { throw 'Android platform tools were not found.' }
if (-not (Test-Path $GodotPath)) { throw 'Pass -GodotPath with the path to Godot.' }
$devices = @(& $adb devices | Where-Object { $_ -match '^\S+\s+device$' } | ForEach-Object { ($_ -split '\s+')[0] })
if (-not $Device) {
    if ($devices.Count -ne 1) { throw 'Connect and unlock one tablet, enable USB debugging and accept its prompt; or select a device with -Device SERIAL.' }
    $Device = $devices[0]
}
if ($Device -notin $devices) { throw 'The selected tablet is not connected and authorized for USB debugging.' }
$savedAppData = $env:APPDATA
$apk = Join-Path $PSScriptRoot 'exports/hollow-vigil-tablet.apk'
$log = Join-Path $PSScriptRoot 'artifacts/tablet-export.log'
try {
    $env:APPDATA = Join-Path $PSScriptRoot 'exports/android-tools/profile'
    New-Item -ItemType Directory -Force (Join-Path $PSScriptRoot 'artifacts') | Out-Null
    & $GodotPath --headless --path $PSScriptRoot --export-debug 'Android Tablet' $apk --quit *> $log
    if ($LASTEXITCODE -ne 0 -or (Select-String $log -Pattern 'SCRIPT ERROR:|^ERROR:(?! Failed to read the root certificate store)')) {
        throw "Tablet export failed. See $log."
    }
    # Use the normal Windows profile for the tablet's existing ADB authorization.
    $env:APPDATA = $savedAppData
    & $adb -s $Device install -r $apk
    if ($LASTEXITCODE -ne 0) { throw 'Tablet installation failed. Existing app data has not been deliberately removed.' }
    $activity = @(& $adb -s $Device shell cmd package resolve-activity --brief 'com.kaiser.hollowvigil') | Where-Object { $_ -match '^com\.kaiser\.hollowvigil/' } | Select-Object -Last 1
    if (-not $activity) { throw 'The installed game has no launcher activity.' }
    & $adb -s $Device shell am start -S -W -n $activity.Trim()
    if ($LASTEXITCODE -ne 0) { throw 'The game could not be launched.' }
    Write-Host 'Hollow Vigil was built, installed and launched on the tablet.'
} finally {
    $env:APPDATA = $savedAppData
}
