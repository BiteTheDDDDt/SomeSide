[CmdletBinding()]
param(
    [ValidateRange(1, 3)][int]$Clients = 3,
    [ValidateRange(1024, 65535)][int]$Port = 27849,
    [switch]$Exported,
    [switch]$Impaired,
    [switch]$Advanced,
    [switch]$Biomes,
    [switch]$MixedLanguages,
    [ValidateRange(0, 12)][int]$FinishAfter = 0
)

$ErrorActionPreference = 'Stop'
if ($Biomes -and ($Advanced -or $FinishAfter -gt 0)) { throw 'Use -Biomes separately from -Advanced or -FinishAfter so all three stages can be observed.' }
$projectDirectory = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$enginePath = Join-Path $PSScriptRoot 'runtime\Godot_v4.7.2-stable_win64_console.exe'
if ($Exported) {
    $enginePath = Join-Path $projectDirectory 'dist\v0.9.0\SomeSide.exe'
    if (-not (Test-Path -LiteralPath $enginePath)) { throw 'Export the game before running with -Exported.' }
} elseif (-not (Test-Path -LiteralPath $enginePath)) {
    & (Join-Path $PSScriptRoot 'install.ps1')
}
$resultPrefix = if ($Exported) { 'network-export-' } else { 'network-' }
if ($Impaired) { $resultPrefix += 'impaired-' }
if ($Biomes) { $resultPrefix += 'biomes-' }
if ($MixedLanguages) { $resultPrefix += 'bilingual-' }
$resultDirectory = Join-Path $PSScriptRoot ('results\' + $resultPrefix + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $resultDirectory -Force | Out-Null
$startedProcesses = @()
$cases = @()
$hostDuration = if ($Biomes) { 52 } elseif ($Advanced) { 40 } else { 18 }
$clientDuration = if ($Biomes) { 48 } elseif ($Advanced) { 36 } else { 14 }
$proxyDuration = if ($Biomes) { 56 } elseif ($Advanced) { 44 } else { 22 }
$processTimeout = if ($Biomes) { 65 } elseif ($Advanced) { 55 } else { 35 }

function Start-SmokePeer([string]$Name, [string]$Role, [int]$Duration, [int]$PeerPort) {
    $reportPath = Join-Path $resultDirectory "$Name.json"
    $stdoutPath = Join-Path $resultDirectory "$Name.stdout.log"
    $stderrPath = Join-Path $resultDirectory "$Name.stderr.log"
    $argumentList = @('--headless')
    if (-not $Exported) { $argumentList += @('--path', ('"' + $projectDirectory + '"')) }
    $argumentList += @(
        '--',
        "--smoke-$Role", "--port=$PeerPort", "--duration=$Duration", "--expected-players=$($Clients + 1)",
        ('"--report=' + $reportPath + '"')
    )
    if ($Role -eq 'host' -and $FinishAfter -gt 0) { $argumentList += "--finish-after=$FinishAfter" }
    if ($Advanced) { $argumentList += '--smoke-advanced' }
    if ($Biomes) { $argumentList += '--smoke-biomes' }
    if ($MixedLanguages) { $argumentList += $(if ($Role -eq 'host') { '--language=en' } else { '--language=zh' }) }
    $process = Start-Process -FilePath $enginePath -ArgumentList $argumentList -WorkingDirectory $projectDirectory -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    # Keep a handle open so Windows PowerShell can still read ExitCode after exit.
    $null = $process.Handle
    return [pscustomobject]@{ Name = $Name; Role = $Role; Process = $process; Report = $reportPath; Stdout = $stdoutPath; Stderr = $stderrPath }
}

try {
    $clientPort = $Port
    $proxyProcess = $null
    $proxyReportPath = Join-Path $resultDirectory 'proxy.json'
    if ($Impaired) {
        if ($Port -ge 65535) { throw 'Impaired mode needs Port + 1 for the local proxy.' }
        $clientPort = $Port + 1
        $pythonPath = (Get-Command python -ErrorAction Stop).Source
        $readyPath = Join-Path $resultDirectory 'proxy.ready'
        $proxyArguments = @(
            ('"' + (Join-Path $PSScriptRoot 'network_proxy.py') + '"'),
            '--listen-port', $clientPort, '--server-port', $Port,
            '--delay-ms', '50', '--jitter-ms', '10', '--loss', '0.02', '--duration', $proxyDuration,
            '--report', ('"' + $proxyReportPath + '"'), '--ready', ('"' + $readyPath + '"')
        )
        $proxyProcess = Start-Process -FilePath $pythonPath -ArgumentList $proxyArguments -WorkingDirectory $projectDirectory -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $resultDirectory 'proxy.stdout.log') -RedirectStandardError (Join-Path $resultDirectory 'proxy.stderr.log')
        $null = $proxyProcess.Handle
        $startedProcesses += $proxyProcess
        $readyTimer = [Diagnostics.Stopwatch]::StartNew()
        while (-not (Test-Path -LiteralPath $readyPath)) {
            if ($proxyProcess.HasExited -or $readyTimer.Elapsed.TotalSeconds -gt 5) { throw 'UDP impairment proxy failed to become ready.' }
            Start-Sleep -Milliseconds 100
        }
    }
    $hostCase = Start-SmokePeer 'host' 'host' $hostDuration $Port
    $cases += $hostCase
    $startedProcesses += $hostCase.Process
    Start-Sleep -Seconds 2
    for ($index = 1; $index -le $Clients; $index++) {
        $clientCase = Start-SmokePeer "client-$index" 'client' $clientDuration $clientPort
        $cases += $clientCase
        $startedProcesses += $clientCase.Process
    }

    $timer = [Diagnostics.Stopwatch]::StartNew()
    while (@($startedProcesses | Where-Object { -not $_.HasExited }).Count -gt 0) {
        if ($timer.Elapsed.TotalSeconds -gt $processTimeout) { throw "Network smoke test exceeded its $processTimeout-second process timeout." }
        Start-Sleep -Milliseconds 250
    }

    $allPassed = $true
    $summaries = @()
    foreach ($case in $cases) {
        $case.Process.WaitForExit()
        $report = $null
        if (Test-Path -LiteralPath $case.Report) {
            $report = Get-Content -LiteralPath $case.Report -Raw | ConvertFrom-Json
        }
        $passed = $null -ne $report -and $report.passed -eq $true -and $case.Process.ExitCode -eq 0
        if ($passed -and $case.Role -eq 'host') { $passed = $report.max_players -ge ($Clients + 1) -and $report.inputs -gt 10 }
        if ($passed -and $case.Role -eq 'client') { $passed = $report.snapshots -gt 10 }
        if ($passed -and $FinishAfter -gt 0) { $passed = $report.phase -eq 'lost' -and $report.screen -eq 'results' }
        if ($passed -and $Advanced) {
            $passed = $report.advanced -eq $true -and $report.observed.deployables -eq $true -and $report.observed.effects -eq $true -and $report.observed.chrono -eq $true
            if ($Clients -eq 3) {
                foreach ($kind in @('boomerang', 'storm', 'lance')) { $passed = $passed -and $kind -in $report.observed.projectile_kinds }
            }
        }
        if ($passed -and $Biomes) {
            $passed = $report.biomes -eq $true
            foreach ($biome in @('rainforest', 'canyon', 'ruins')) { $passed = $passed -and $biome -in $report.biome_observed.biomes }
            foreach ($kind in @('crawler', 'spitter', 'spore_moth', 'drone', 'charger', 'burrower', 'sentinel', 'skirmisher', 'conductor', 'boss')) { $passed = $passed -and $kind -in $report.biome_observed.enemy_kinds }
            foreach ($style in @('spore', 'stone', 'prism')) { $passed = $passed -and $style -in $report.biome_observed.boss_styles }
            foreach ($shape in @('line', 'circle')) { $passed = $passed -and $shape -in $report.biome_observed.hazard_shapes }
            $passed = $passed -and @($report.biome_observed.attack_kinds).Count -ge 6
        }
        if ($passed -and $MixedLanguages) {
            $expectedLanguage = if ($case.Role -eq 'host') { 'en' } else { 'zh' }
            $passed = $report.language -eq $expectedLanguage
        }
        $runtimeErrors = @()
        if (Test-Path -LiteralPath $case.Stderr) {
            $runtimeErrors = @(Select-String -LiteralPath $case.Stderr -Pattern '^(SCRIPT ERROR|ERROR):')
        }
        $passed = $passed -and $runtimeErrors.Count -eq 0
        $allPassed = $allPassed -and $passed
        $summaries += [pscustomobject]@{ name = $case.Name; passed = $passed; exit_code = $case.Process.ExitCode; runtime_errors = $runtimeErrors.Count; report = $report }
        Write-Host ("{0}: passed={1}, exit={2}" -f $case.Name, $passed, $case.Process.ExitCode)
        if (-not $passed) {
            if (Test-Path -LiteralPath $case.Stdout) { Get-Content -LiteralPath $case.Stdout -Tail 30 | Write-Host }
            if (Test-Path -LiteralPath $case.Stderr) { Get-Content -LiteralPath $case.Stderr -Tail 30 | Write-Host }
        }
    }
    $proxyReport = $null
    if ($Impaired) {
        $proxyProcess.WaitForExit()
        if (Test-Path -LiteralPath $proxyReportPath) { $proxyReport = Get-Content -LiteralPath $proxyReportPath -Raw | ConvertFrom-Json }
        $proxyPassed = $null -ne $proxyReport -and $proxyReport.passed -eq $true -and $proxyProcess.ExitCode -eq 0 -and $proxyReport.clients -eq $Clients
        $allPassed = $allPassed -and $proxyPassed
        Write-Host ("UDP proxy: passed={0}, clients={1}" -f $proxyPassed, $proxyReport.clients)
    }
    $summary = [pscustomobject]@{ passed = $allPassed; exported = [bool]$Exported; impaired = [bool]$Impaired; advanced = [bool]$Advanced; biomes = [bool]$Biomes; mixed_languages = [bool]$MixedLanguages; finish_after = $FinishAfter; clients = $Clients; port = $Port; proxy = $proxyReport; cases = $summaries }
    $summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $resultDirectory 'summary.json') -Encoding UTF8
    Write-Host "Reports: $resultDirectory"
    if (-not $allPassed) { exit 1 }
} finally {
    foreach ($process in $startedProcesses) {
        if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue }
    }
}
