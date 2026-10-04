[CmdletBinding()]
param(
    [ValidateRange(1, 3)][int]$Clients = 1,
    [ValidateRange(1024, 65534)][int]$Port = 27920,
    [ValidateRange(12, 60)][int]$Duration = 14,
    [switch]$Impaired
)

$ErrorActionPreference = 'Stop'
$projectDirectory = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$enginePath = Join-Path $PSScriptRoot 'runtime\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $enginePath)) { throw 'Install the project Godot runtime before running this acceptance test.' }
$suffix = if ($Impaired) { 'impaired' } else { 'local' }
$resultDirectory = Join-Path $PSScriptRoot ("results\network-controls-v09-$($Clients + 1)p-$suffix-" + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $resultDirectory -Force | Out-Null
$startedProcesses = @()
$cases = @()
$proxyProcess = $null
$proxyReportPath = Join-Path $resultDirectory 'proxy.json'

function Start-ControlPeer([string]$Name, [string]$Role, [int]$Seconds, [int]$PeerPort) {
    $reportPath = Join-Path $resultDirectory "$Name.json"
    $stdoutPath = Join-Path $resultDirectory "$Name.stdout.log"
    $stderrPath = Join-Path $resultDirectory "$Name.stderr.log"
    $arguments = @('--headless', '--path', ('"' + $projectDirectory + '"'), '--script', 'res://tools/network-controls-v09.gd', '--', "--smoke-$Role", "--port=$PeerPort", "--duration=$Seconds", "--expected-players=$($Clients + 1)", ('"--report=' + $reportPath + '"'))
    $process = Start-Process -FilePath $enginePath -ArgumentList $arguments -WorkingDirectory $projectDirectory -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $null = $process.Handle
    return [pscustomobject]@{ Name = $Name; Role = $Role; Process = $process; Report = $reportPath; Stdout = $stdoutPath; Stderr = $stderrPath }
}

try {
    $clientPort = $Port
    if ($Impaired) {
        $clientPort = $Port + 1
        $pythonPath = (Get-Command python -ErrorAction Stop).Source
        $readyPath = Join-Path $resultDirectory 'proxy.ready'
        $proxyArguments = @(('"' + (Join-Path $PSScriptRoot 'network_proxy.py') + '"'), '--listen-port', $clientPort, '--server-port', $Port, '--delay-ms', '50', '--jitter-ms', '10', '--loss', '0.02', '--duration', ($Duration + 8), '--report', ('"' + $proxyReportPath + '"'), '--ready', ('"' + $readyPath + '"'))
        $proxyProcess = Start-Process -FilePath $pythonPath -ArgumentList $proxyArguments -WorkingDirectory $projectDirectory -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $resultDirectory 'proxy.stdout.log') -RedirectStandardError (Join-Path $resultDirectory 'proxy.stderr.log')
        $null = $proxyProcess.Handle
        $startedProcesses += $proxyProcess
        $readyTimer = [Diagnostics.Stopwatch]::StartNew()
        while (-not (Test-Path -LiteralPath $readyPath)) {
            if ($proxyProcess.HasExited -or $readyTimer.Elapsed.TotalSeconds -gt 5) { throw 'UDP impairment proxy failed to become ready.' }
            Start-Sleep -Milliseconds 100
        }
    }
    $hostCase = Start-ControlPeer 'host' 'host' ($Duration + 4) $Port
    $cases += $hostCase
    $startedProcesses += $hostCase.Process
    Start-Sleep -Seconds 2
    for ($index = 1; $index -le $Clients; $index++) {
        $clientCase = Start-ControlPeer "client-$index" 'client' $Duration $clientPort
        $cases += $clientCase
        $startedProcesses += $clientCase.Process
    }

    $timer = [Diagnostics.Stopwatch]::StartNew()
    while (@($startedProcesses | Where-Object { -not $_.HasExited }).Count -gt 0) {
        if ($timer.Elapsed.TotalSeconds -gt $Duration + 20) { throw 'Network controls acceptance exceeded its bounded process timeout.' }
        Start-Sleep -Milliseconds 250
    }

    $allPassed = $true
    $summaries = @()
    foreach ($case in $cases) {
        $case.Process.WaitForExit()
        $report = $null
        if (Test-Path -LiteralPath $case.Report) { $report = Get-Content -LiteralPath $case.Report -Raw | ConvertFrom-Json }
        $runtimeErrors = @()
        if (Test-Path -LiteralPath $case.Stderr) { $runtimeErrors = @(Select-String -LiteralPath $case.Stderr -Pattern '^(SCRIPT ERROR|ERROR):') }
        $passed = $null -ne $report -and $report.passed -eq $true -and $case.Process.ExitCode -eq 0 -and $runtimeErrors.Count -eq 0
        $allPassed = $allPassed -and $passed
        $summaries += [pscustomobject]@{ name = $case.Name; passed = $passed; exit_code = $case.Process.ExitCode; runtime_errors = $runtimeErrors.Count; report = $report }
        Write-Host ("{0}: passed={1}, exit={2}" -f $case.Name, $passed, $case.Process.ExitCode)
        if ($case.Role -eq 'host' -and $null -ne $report) {
            foreach ($entry in $report.authoritative.PSObject.Properties) {
                Write-Host ("  authority peer {0}: {1} jumps, apex {2:N2}..{3:N2}px" -f $entry.Name, $entry.Value.completed_jumps, $entry.Value.minimum_apex_px, $entry.Value.maximum_apex_px)
            }
        }
        if (-not $passed) {
            if (Test-Path -LiteralPath $case.Stdout) { Get-Content -LiteralPath $case.Stdout -Tail 12 | Write-Host }
            if (Test-Path -LiteralPath $case.Stderr) { Get-Content -LiteralPath $case.Stderr -Tail 20 | Write-Host }
        }
    }
    $proxyReport = $null
    if ($Impaired) {
        if (Test-Path -LiteralPath $proxyReportPath) { $proxyReport = Get-Content -LiteralPath $proxyReportPath -Raw | ConvertFrom-Json }
        $proxyPassed = $null -ne $proxyReport -and $proxyReport.passed -eq $true -and $proxyProcess.ExitCode -eq 0 -and $proxyReport.clients -eq $Clients
        $allPassed = $allPassed -and $proxyPassed
        Write-Host ("UDP proxy: passed={0}, clients={1}" -f $proxyPassed, $proxyReport.clients)
    }
    [pscustomobject]@{ passed = $allPassed; clients = $Clients; impaired = [bool]$Impaired; duration = $Duration; port = $Port; proxy = $proxyReport; cases = $summaries } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $resultDirectory 'summary.json') -Encoding UTF8
    Write-Host "Reports: $resultDirectory"
    if (-not $allPassed) { exit 1 }
} finally {
    # Only processes created by this invocation are eligible for cleanup.
    foreach ($process in $startedProcesses) {
        if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue }
    }
}
