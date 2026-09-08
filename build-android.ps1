[CmdletBinding()]
param([string]$GodotPath = "$env:USERPROFILE\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe")
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$names = @('APPDATA','JAVA_HOME','ANDROID_HOME','GRADLE_OPTS','GODOT_ANDROID_KEYSTORE_RELEASE_PATH','GODOT_ANDROID_KEYSTORE_RELEASE_USER','GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD')
$saved = @{}
foreach ($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
try {
    $env:APPDATA = (Resolve-Path 'exports/android-tools/profile').Path
    $env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
    $env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
    # Persistent Gradle daemons retain the export's output pipe on Windows.
    $env:GRADLE_OPTS = "$env:GRADLE_OPTS -Dorg.gradle.daemon=false"
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = (Resolve-Path 'exports/android-signing/hollow-vigil-upload.jks').Path
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = 'hollow-vigil-upload'
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = Get-Content 'exports/android-signing/upload-password.txt' -Raw
    & $GodotPath --headless --path $PSScriptRoot --export-release Android 'exports/hollow-vigil-1.0.9.aab' --quit *> artifacts/android-export.log
    if ($LASTEXITCODE -ne 0 -or (Select-String artifacts/android-export.log -Pattern 'SCRIPT ERROR:|^ERROR:(?! Failed to read the root certificate store)')) {
        throw 'Android export failed. See artifacts/android-export.log.'
    }
    Get-Item 'exports/hollow-vigil-1.0.9.aab'
} finally {
    foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
}
