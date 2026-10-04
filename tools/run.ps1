[CmdletBinding()]
param(
    [ValidateSet('Run', 'Editor', 'Test', 'Export')]
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

switch ($Mode) {
    'Run' {
        & $enginePath --path $projectDirectory @GameArguments
    }
    'Editor' {
        & $enginePath --editor --path $projectDirectory @GameArguments
    }
    'Test' {
        foreach ($testScript in @('test_simulation.gd', 'test_movement.gd', 'test_input.gd', 'test_controls.gd', 'test_loot.gd', 'test_content.gd', 'test_rewards.gd', 'test_enemies.gd', 'test_stress.gd', 'test_director.gd', 'test_weapon_pose.gd', 'test_weapon_feedback.gd', 'test_appearance.gd', 'test_enemy_visuals.gd', 'test_visuals.gd', 'test_render_cache.gd', 'test_sprite_atlas.gd', 'test_ui.gd', 'test_localization.gd', 'test_fps.gd', 'test_combat_fx.gd', 'test_pixel_actors.gd', 'test_actor_motion.gd', 'test_actor_animation.gd')) {
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
        New-Item -ItemType Directory -Path (Join-Path $projectDirectory 'dist\v0.12.0') -Force | Out-Null
        & $enginePath --headless --path $projectDirectory --editor --import
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $enginePath --headless --path $projectDirectory --export-release 'Windows Desktop' 'dist/v0.12.0/SomeSide.exe' @GameArguments
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'licenses\GODOT-LICENSE.txt') -Destination (Join-Path $projectDirectory 'dist\v0.12.0\GODOT-LICENSE.txt') -Force
        Copy-Item -LiteralPath (Join-Path $projectDirectory 'assets\fonts\OFL.txt') -Destination (Join-Path $projectDirectory 'dist\v0.12.0\FONT-OFL.txt') -Force
    }
}
exit $LASTEXITCODE
