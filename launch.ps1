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
        if ($Tests -or $MobileTests -or $Check) {
            Invoke-Godot -Name 'tuning-schema' -EngineArguments @('--headless', '--script', 'res://tests/tuning_schema_runner.gd')
        }
        if ($Tests -or $Check) {
            Invoke-Godot -Name 'tower-expansion' -EngineArguments @('--headless', '--script', 'res://tests/tower_expansion_runner.gd')
            Invoke-Godot -Name 'tower-expansion-balance' -EngineArguments @('--headless', '--script', 'res://tests/tower_expansion_balance_runner.gd')
            Invoke-Godot -Name 'tower-expansion-stress' -EngineArguments @('--headless', '--script', 'res://tests/tower_expansion_stress_runner.gd')
            Invoke-Godot -Name 'branches' -EngineArguments @('--headless', '--script', 'res://tests/branch_runner.gd')
            Invoke-Godot -Name 'first-property' -EngineArguments @('--headless', '--script', 'res://tests/first_property_runner.gd')
            Invoke-Godot -Name 'audio' -EngineArguments @('--headless', '--script', 'res://tests/audio_runner.gd')
            Invoke-Godot -Name 'audio-pitch' -EngineArguments @('--headless', '--script', 'res://tests/audio_pitch_runner.gd')
            Invoke-Godot -Name 'ground-placement' -EngineArguments @('--headless', '--script', 'res://tests/ground_placement_runner.gd')
            Invoke-Godot -Name 'unit' -EngineArguments @('--headless', '--script', 'res://tests/test_runner.gd')
        }
        if ($UnifiedTests -or $Check) {
            Invoke-Godot -Name 'save-exit' -EngineArguments @('--headless', '--script', 'res://tests/rendered/save_exit_runner.gd')
            Invoke-Godot -Name 'saved-slot-continue' -EngineArguments @('--headless', '--script', 'res://tests/rendered/saved_slot_continue_runner.gd')
            Invoke-Godot -Name 'save-slot-deletion' -EngineArguments @('--script', 'res://tests/rendered/save_slot_deletion_runner.gd')
            Invoke-Godot -Name 'unified-persistence' -EngineArguments @('--headless', '--script', 'res://tests/unified_persistence_runner.gd')
            Invoke-Godot -Name 'private-backups' -EngineArguments @('--headless', '--script', 'res://tests/private_backups_runner.gd')
            Invoke-Godot -Name 'backup-deletion' -EngineArguments @('--headless', '--script', 'res://tests/backup_deletion_runner.gd')
            Invoke-Godot -Name 'backup-delete-ui' -EngineArguments @('--script', 'res://tests/rendered/backup_deletion_menu_runner.gd')
            Invoke-Godot -Name 'unified-menu' -EngineArguments @('--script', 'res://tests/rendered/unified_menu_runner.gd')
            Invoke-Godot -Name 'recovery-menu' -EngineArguments @('--script', 'res://tests/rendered/recovery_menu_runner.gd')
        }
        if ($Smoke -or $Check) {
            Invoke-Godot -Name 'visual' -EngineArguments @('--script', 'res://tests/rendered/visual_runner.gd')
        }
        if ($MobileTests -or $Check) {
            Invoke-Godot -Name 'touch-scroll-scope' -EngineArguments @('--headless', '--script', 'res://tests/touch_scroll_scope_runner.gd')
            Invoke-Godot -Name 'mobile-navigation' -EngineArguments @('--script', 'res://tests/rendered/mobile_navigation_runner.gd')
            Invoke-Godot -Name 'mobile-menu-audit' -EngineArguments @('--script', 'res://tests/rendered/mobile_menu_audit_runner.gd')
            Invoke-Godot -Name 'mobile-scroll' -EngineArguments @('--script', 'res://tests/rendered/mobile_scroll_runner.gd')
            Invoke-Godot -Name 'mobile-playthrough' -EngineArguments @('--script', 'res://tests/rendered/mobile_playthrough_runner.gd')
            Invoke-Godot -Name 'mobile-picker' -EngineArguments @('--script', 'res://tests/rendered/illustrated_picker_touch_runner.gd')
            Invoke-Godot -Name 'mobile-campaign-upgrades' -EngineArguments @('--script', 'res://tests/rendered/campaign_upgrade_runner.gd')
            Invoke-Godot -Name 'mobile-campaign-controls' -EngineArguments @('--script', 'res://tests/rendered/mobile_campaign_controls_runner.gd')
            Invoke-Godot -Name 'campaign-navigation' -EngineArguments @('--script', 'res://tests/rendered/campaign_navigation_runner.gd')
            Invoke-Godot -Name 'mobile-context-actions' -EngineArguments @('--script', 'res://tests/rendered/mobile_context_actions_runner.gd')
            Invoke-Godot -Name 'mobile-equipment' -EngineArguments @('--script', 'res://tests/rendered/relic_runner.gd')
        }
        if ($StyleTests -or $Check) {
            Invoke-Godot -Name 'campaign-portals' -EngineArguments @('--script', 'res://tests/rendered/campaign_portal_runner.gd')
            Invoke-Godot -Name 'campaign-landscape' -EngineArguments @('--script', 'res://tests/rendered/campaign_landscape_runner.gd')
            Invoke-Godot -Name 'campaign-map' -EngineArguments @('--script', 'res://tests/rendered/campaign_map_runner.gd')
            Invoke-Godot -Name 'baked-map' -EngineArguments @('--script', 'res://tests/rendered/baked_map_runner.gd')
            Invoke-Godot -Name 'campaign-map-menu' -EngineArguments @('--script', 'res://tests/rendered/campaign_map_menu_runner.gd')
            Invoke-Godot -Name 'campaign-hud' -EngineArguments @('--script', 'res://tests/rendered/campaign_hud_runner.gd')
            Invoke-Godot -Name 'parchment-corners' -EngineArguments @('--script', 'res://tests/rendered/parchment_corner_runner.gd')
            Invoke-Godot -Name 'wave-menu' -EngineArguments @('--script', 'res://tests/rendered/wave_menu_runner.gd')
            Invoke-Godot -Name 'wave-rules' -EngineArguments @('--script', 'res://tests/rendered/wave_rules_runner.gd')
            Invoke-Godot -Name 'campaign-global-rules' -EngineArguments @('--script', 'res://tests/rendered/campaign_configuration_runner.gd')
            # Ground build replaces the former platform card/confirmation flow.
            Invoke-Godot -Name 'tower-level-indicator' -EngineArguments @('--script', 'res://tests/rendered/tower_level_indicator_runner.gd')
            Invoke-Godot -Name 'tower-upgrade-preview' -EngineArguments @('--script', 'res://tests/rendered/tower_upgrade_preview_runner.gd')
            Invoke-Godot -Name 'tower-expansion-art' -EngineArguments @('--script', 'res://tests/rendered/tower_expansion_art_runner.gd')
            Invoke-Godot -Name 'ground-build' -EngineArguments @('--script', 'res://tests/rendered/ground_build_runner.gd')
            Invoke-Godot -Name 'tower-framing' -EngineArguments @('--script', 'res://tests/rendered/tower_framing_runner.gd')
            Invoke-Godot -Name 'welcome-menu' -EngineArguments @('--script', 'res://tests/rendered/welcome_menu_checks.gd')
            Invoke-Godot -Name 'welcome-startup' -EngineArguments @('--script', 'res://tests/rendered/welcome_layout_runner.gd')
            Invoke-Godot -Name 'ui-style' -EngineArguments @('--script', 'res://tests/rendered/ui_style_checks.gd')
            Invoke-Godot -Name 'menu-layout' -EngineArguments @('--script', 'res://tests/rendered/menu_layout_checks.gd')
            Invoke-Godot -Name 'developer-layout' -EngineArguments @('--script', 'res://tests/rendered/developer_layout_checks.gd')
            Invoke-Godot -Name 'portal-rosters-ui' -EngineArguments @('--script', 'res://tests/rendered/portal_roster_checks.gd')
        }
        if ($TerrainTests -or $Check) {
            Invoke-Godot -Name 'campaign-terrain' -EngineArguments @('--script', 'res://tests/rendered/campaign_terrain_checks.gd')
            Invoke-Godot -Name 'terrain' -EngineArguments @('--script', 'res://tests/rendered/terrain_palette_checks.gd')
            Invoke-Godot -Name 'castle-art' -EngineArguments @('--script', 'res://tests/rendered/castle_art_checks.gd')
        }
        if ($ArtSmoke -or $Check) {
            Invoke-Godot -Name 'ironspike-aim' -EngineArguments @('--script', 'res://tests/rendered/ironspike_aim_runner.gd')
            Invoke-Godot -Name 'gear-art' -EngineArguments @('--script', 'res://tests/rendered/gear_art_runner.gd')
            Invoke-Godot -Name 'portal-upgrades' -EngineArguments @('--script', 'res://tests/rendered/portal_upgrade_checks.gd')
            Invoke-Godot -Name 'branch-visual' -EngineArguments @('--script', 'res://tests/rendered/branch_visual_runner.gd')
            Invoke-Godot -Name 'artwork' -EngineArguments @('--script', 'res://tests/rendered/artwork_smoke.gd')
            Invoke-Godot -Name 'tower-upgrade-art' -EngineArguments @('--script', 'res://tests/rendered/tower_upgrade_art_checks.gd')
            Invoke-Godot -Name 'construction-effect' -EngineArguments @('--script', 'res://tests/rendered/construction_effect_runner.gd')
            Invoke-Godot -Name 'enemy-art' -EngineArguments @('--script', 'res://tests/rendered/enemy_art_checks.gd')
            Invoke-Godot -Name 'boss-art' -EngineArguments @('--script', 'res://tests/rendered/boss_art_checks.gd')
        }
        if ($TerrainPreview) {
            Invoke-Godot -Name 'preview' -EngineArguments @('--script', 'res://tests/previews/terrain_preview.gd')
        }
        if (@($modes).Count -eq 0) { Invoke-Godot -Name 'game' -EngineArguments @() }
    }
} finally {
    $env:APPDATA = $savedAppData
    $env:LOCALAPPDATA = $savedLocalAppData
}
