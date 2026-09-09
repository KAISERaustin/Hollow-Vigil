[CmdletBinding()]
param(
    [switch]$Editor,
    [switch]$Tests,
    [switch]$Smoke,
    [switch]$StyleTests,
    [switch]$MobileTests,
    [switch]$UnifiedTests,
    [switch]$TerrainTests,
    [switch]$TerrainPreview,
    [switch]$ArtSmoke,
    [switch]$Check,
    [switch]$Import,
    [string]$GodotPath = $env:GODOT_PATH
)

$ErrorActionPreference = 'Stop'
$projectPath = $PSScriptRoot
$modes = @($Editor, $Tests, $Smoke, $StyleTests, $MobileTests, $UnifiedTests, $TerrainTests, $TerrainPreview, $ArtSmoke, $Check, $Import) | Where-Object { $_ }
if (@($modes).Count -gt 1) { throw 'Choose one launch mode at a time.' }

if (-not $GodotPath) {
    foreach ($name in @('godot', 'godot4', 'godot-mono')) {
        $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue
        if ($command) { $GodotPath = $command.Source; break }
    }
}
if (-not $GodotPath) {
    # Preserve the original local setup while allowing any explicit installation.
    $GodotPath = Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw 'Godot was not found. Pass -GodotPath C:\path\to\godot.exe or set GODOT_PATH.'
}
$enginePath = (Resolve-Path -LiteralPath $GodotPath).Path
$artifactPath = Join-Path $projectPath 'artifacts'
New-Item -ItemType Directory -Force -Path $artifactPath | Out-Null

function Invoke-Godot {
    param([string]$Name, [string[]]$EngineArguments)
    $logPath = Join-Path $artifactPath ($Name + '.log')
    if (Test-Path -LiteralPath $logPath) { Remove-Item -LiteralPath $logPath }
    $scriptIndex = [Array]::IndexOf($EngineArguments, '--script')
    if ($scriptIndex -ge 0) {
        & $enginePath --headless --path $projectPath --script $EngineArguments[$scriptIndex + 1] --check-only
        if ($LASTEXITCODE -ne 0) { throw "$Name failed script validation." }
    }
    & $enginePath --path $projectPath --log-file $logPath @EngineArguments
    if ($LASTEXITCODE -ne 0) { throw "$Name failed (exit $LASTEXITCODE). See $logPath." }
    if (Test-Path -LiteralPath $logPath) {
        # Godot can return zero after GDScript errors. Do not report a false pass.
        $errors = Select-String -LiteralPath $logPath -Pattern 'SCRIPT ERROR:|Parse Error:|^ERROR:(?! Failed to read the root certificate store\.)'
        if ($errors) { throw "$Name reported engine or script errors. See $logPath." }
    }
}

$savedAppData = $env:APPDATA
$savedLocalAppData = $env:LOCALAPPDATA
try {
    $runtimePath = Join-Path $projectPath '.runtime'
    if ($Tests -or $Smoke -or $StyleTests -or $MobileTests -or $UnifiedTests -or $TerrainTests -or $TerrainPreview -or $ArtSmoke -or $Check -or $Import) {
        $runtimePath = Join-Path $runtimePath 'tests'
    }
    $env:APPDATA = Join-Path $runtimePath 'Roaming'
    $env:LOCALAPPDATA = Join-Path $runtimePath 'Local'
    New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null

    if ($Editor) {
        Invoke-Godot -Name 'editor-session' -EngineArguments @('--editor')
    } else {
        # Registers script classes and imports assets on a completely clean checkout.
        Invoke-Godot -Name 'import' -EngineArguments @('--headless', '--editor', '--import')
        if ($Tests -or $Check) {
            foreach ($runner in @('source_load_runner', 'stats_system_runner', 'hex_support_runner', 'portal_attributes_runner', 'campaign_runner', 'campaign_configuration_runner', 'wave_editor_runner', 'campaign_export_runner', 'campaign_expansion_runner', 'campaign_ground_save_runner', 'tuning_schema_runner')) {
                Invoke-Godot -Name $runner -EngineArguments @('--headless', '--script', "res://tests/$runner.gd")
            }
        }
        if ($UnifiedTests -or $Check) {
            foreach ($runner in @('campaign_only_runner', 'campaign_private_backup_runner', 'campaign_backup_runner', 'account_session_runner', 'bug_reports_runner')) {
                Invoke-Godot -Name $runner -EngineArguments @('--headless', '--script', "res://tests/$runner.gd")
            }
        }
        if ($Smoke -or $StyleTests -or $MobileTests -or $Check) {
            Invoke-Godot -Name 'welcome-layout' -EngineArguments @('--script', 'res://tests/rendered/welcome_layout_runner.gd')
            Invoke-Godot -Name 'campaign-navigation' -EngineArguments @('--script', 'res://tests/rendered/campaign_navigation_runner.gd')
        }
        if ($MobileTests -or $Check) {
            Invoke-Godot -Name 'stats-editor' -EngineArguments @('--script', 'res://tests/rendered/stats_editor_runner.gd')
            Invoke-Godot -Name 'rules-navigation' -EngineArguments @('--script', 'res://tests/rendered/rules_navigation_runner.gd')
			Invoke-Godot -Name 'rules-back' -EngineArguments @('--script', 'res://tests/rendered/rules_back_runner.gd')
            Invoke-Godot -Name 'portal-attributes' -EngineArguments @('--script', 'res://tests/rendered/portal_attributes_runner.gd')
            Invoke-Godot -Name 'wave-editor-touch' -EngineArguments @('--script', 'res://tests/rendered/wave_editor_runner.gd')
            Invoke-Godot -Name 'campaign-touch' -EngineArguments @('--script', 'res://tests/rendered/mobile_campaign_controls_runner.gd')
            Invoke-Godot -Name 'picker-touch' -EngineArguments @('--script', 'res://tests/rendered/illustrated_picker_touch_runner.gd')
            Invoke-Godot -Name 'save-slot-picker' -EngineArguments @('--script', 'res://tests/rendered/save_slot_picker_runner.gd')
        }
        if ($TerrainTests -or $TerrainPreview -or $Check) {
            Invoke-Godot -Name 'campaign-terrain' -EngineArguments @('--script', 'res://tests/rendered/campaign_terrain_checks.gd')
        }
        if ($ArtSmoke -or $Check) {
			Invoke-Godot -Name 'hex-effects' -EngineArguments @('--script', 'res://tests/rendered/hex_effect_runner.gd')
            Invoke-Godot -Name 'gear-art' -EngineArguments @('--script', 'res://tests/rendered/gear_art_runner.gd')
            Invoke-Godot -Name 'construction-effect' -EngineArguments @('--script', 'res://tests/rendered/construction_effect_runner.gd')
        }
        if (@($modes).Count -eq 0) { Invoke-Godot -Name 'game' -EngineArguments @() }
    }
} finally {
    $env:APPDATA = $savedAppData
    $env:LOCALAPPDATA = $savedLocalAppData
}
