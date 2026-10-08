[CmdletBinding()]
param(
    [ValidateSet('Run', 'Editor', 'Test', 'Export', 'ExportWeb')]
    [string]$Mode = 'Run',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GameArguments = @()
)

$ErrorActionPreference = 'Stop'
$projectDirectory = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$runtimeDirectory = Join-Path $PSScriptRoot 'runtime'
$enginePath = Join-Path $runtimeDirectory 'Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $enginePath)) {
    & (Join-Path $PSScriptRoot 'install.ps1')
}
if (-not (Test-Path -LiteralPath (Join-Path $projectDirectory 'project.godot'))) {
    throw "Cannot find project.godot in $projectDirectory"
}

$projectVersion = [regex]::Match((Get-Content -LiteralPath (Join-Path $projectDirectory 'project.godot') -Raw), 'config/version="([^"]+)"').Groups[1].Value
if (-not $projectVersion) { throw 'Missing project version.' }
if ($Mode -in @('Export', 'ExportWeb')) {
    $distRoot = Join-Path $projectDirectory 'dist'
    New-Item -ItemType Directory -Path $distRoot -Force | Out-Null
    # Exported PNG icons are output, not project source assets.
    New-Item -ItemType File -Path (Join-Path $distRoot '.gdignore') -Force | Out-Null
}

switch ($Mode) {
    'Run' {
        & $enginePath --path $projectDirectory @GameArguments
    }
    'Editor' {
        & $enginePath --editor --path $projectDirectory @GameArguments
    }
    'Test' {
        foreach ($testScript in @(
            'test_procs.gd', 'test_proc_feedback.gd', 'test_projectile_guidance.gd', 'test_simulation.gd', 'test_movement.gd', 'test_input.gd', 'test_controls.gd', 'test_character_abilities.gd', 'test_ability_feedback.gd', 'test_loot.gd', 'test_shop_motion.gd', 'test_facilities.gd', 'test_chest_tiers.gd', 'test_content.gd', 'test_rewards.gd', 'test_coin_rewards.gd', 'test_action_feedback.gd', 'test_audio.gd', 'test_audio_integration.gd', 'test_melee_audio.gd', 'test_melee_integration.gd', 'test_event_stages.gd', 'test_melee_pose.gd', 'test_weapon_actions.gd', 'test_ranged_actions.gd', 'test_enemies.gd', 'test_hazard_timing.gd', 'test_enemy_navigation.gd', 'test_stress.gd', 'test_director.gd', 'test_weapon_pose.gd', 'test_weapon_art.gd', 'test_item_icons.gd', 'test_weapon_feedback.gd', 'test_appearance.gd', 'test_enemy_visuals.gd', 'test_enemy_attack_visuals.gd', 'test_combat_geometry.gd', 'test_beam_envelope.gd', 'test_natural_warnings.gd', 'test_attack_fx_sprites.gd', 'test_visuals.gd', 'test_render_cache.gd', 'test_sprite_atlas.gd', 'test_ui.gd', 'test_localization.gd', 'test_fps.gd', 'test_combat_fx.gd', 'test_pixel_actors.gd', 'test_illustrated_players.gd', 'test_actor_motion.gd', 'test_actor_animation.gd', 'test_player_gait.gd', 'test_web_runtime.gd', 'test_web_background.gd')) {
            $testOutput = @(& $enginePath --headless --path $projectDirectory --script ('res://tests/' + $testScript) @GameArguments 2>&1)
            $testExitCode = $LASTEXITCODE
            $testOutput | Write-Output
            # Godot can report a script error yet exit 0; assertions alone must
            # not make a broken test process look successful.
            $runtimeErrors = @($testOutput | Where-Object { $_.ToString() -match '^(SCRIPT ERROR|ERROR):' })
            $completed = @($testOutput | Where-Object { $_.ToString() -match '_TEST_RESULT passed=\d+ failed=0$' })
            if ($testExitCode -ne 0 -or $runtimeErrors.Count -gt 0 -or $completed.Count -ne 1) {
                throw "Test $testScript failed or produced runtime errors."
            }
        }
    }
    'Export' {
        $templatePath = Join-Path $runtimeDirectory 'templates\windows_release_x86_64.exe'
        if (-not (Test-Path -LiteralPath $templatePath)) {
            & (Join-Path $PSScriptRoot 'install.ps1') -Templates
        }
        New-Item -ItemType Directory -Path (Join-Path $projectDirectory "dist\v$projectVersion") -Force | Out-Null
        & $enginePath --headless --path $projectDirectory --editor --import
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $enginePath --headless --path $projectDirectory --export-release 'Windows Desktop' "dist/v$projectVersion/SomeSide.exe" @GameArguments
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'licenses\GODOT-LICENSE.txt') -Destination (Join-Path $projectDirectory "dist\v$projectVersion\GODOT-LICENSE.txt") -Force
        Copy-Item -LiteralPath (Join-Path $projectDirectory 'assets\fonts\OFL.txt') -Destination (Join-Path $projectDirectory "dist\v$projectVersion\FONT-OFL.txt") -Force
    }
    'ExportWeb' {
        & (Join-Path $PSScriptRoot 'install.ps1') -WebTemplates
        $webDirectory = Join-Path $projectDirectory "dist\v$projectVersion-web"
        New-Item -ItemType Directory -Path $webDirectory -Force | Out-Null
        & $enginePath --headless --path $projectDirectory --editor --import
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $enginePath --headless --path $projectDirectory --export-release 'Web' (Join-Path $webDirectory 'index.html') @GameArguments
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'licenses\GODOT-LICENSE.txt') -Destination $webDirectory -Force
        Copy-Item -LiteralPath (Join-Path $projectDirectory 'assets\fonts\OFL.txt') -Destination (Join-Path $webDirectory 'FONT-OFL.txt') -Force
    }
}
exit $LASTEXITCODE
