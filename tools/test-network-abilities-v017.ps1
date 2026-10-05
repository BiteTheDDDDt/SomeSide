[CmdletBinding()]
param(
    [ValidateSet(3)][int]$Clients = 3,
    [ValidateRange(1024, 65534)][int]$Port = 27982,
    [ValidateRange(24, 40)][int]$Duration = 24
)

$ErrorActionPreference = 'Stop'
$projectDirectory = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$enginePath = Join-Path $PSScriptRoot 'runtime\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $enginePath)) { throw 'The project Godot runtime is required.' }
$resultDirectory = Join-Path $PSScriptRoot ("results\network-abilities-v017-$($Clients + 1)p-" + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $resultDirectory -Force | Out-Null
$cases = @()

function Start-AbilityPeer([string]$Name, [string]$Role, [int]$Seconds) {
    $reportPath = Join-Path $resultDirectory "$Name.json"
    $stdoutPath = Join-Path $resultDirectory "$Name.stdout.log"
    $stderrPath = Join-Path $resultDirectory "$Name.stderr.log"
    $arguments = @('--headless', '--path', ('"' + $projectDirectory + '"'), '--script', 'res://tools/network-abilities-v017.gd', '--', "--smoke-$Role", "--port=$Port", "--duration=$Seconds", "--expected-players=$($Clients + 1)", ('"--report=' + $reportPath + '"'))
    $process = Start-Process -FilePath $enginePath -ArgumentList $arguments -WorkingDirectory $projectDirectory -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $null = $process.Handle
    return [pscustomobject]@{ Name = $Name; Role = $Role; Process = $process; Report = $reportPath; Stdout = $stdoutPath; Stderr = $stderrPath }
}

try {
    $cases += Start-AbilityPeer 'host' 'host' ($Duration + 4)
    Start-Sleep -Seconds 2
    for ($index = 1; $index -le $Clients; $index++) {
        $cases += Start-AbilityPeer "client-$index" 'client' $Duration
    }
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while (@($cases | Where-Object { -not $_.Process.HasExited }).Count -gt 0) {
        if ($timer.Elapsed.TotalSeconds -gt $Duration + 15) { throw 'Character ability network acceptance exceeded its bounded timeout.' }
        Start-Sleep -Milliseconds 250
    }
    $allPassed = $true
    $summaries = @()
    foreach ($case in $cases) {
        $case.Process.WaitForExit()
        $report = $null
        if (Test-Path -LiteralPath $case.Report) { $report = Get-Content -LiteralPath $case.Report -Raw | ConvertFrom-Json }
        $errors = @()
        if (Test-Path -LiteralPath $case.Stderr) { $errors = @(Select-String -LiteralPath $case.Stderr -Pattern '^(SCRIPT ERROR|ERROR):') }
        $passed = $null -ne $report -and $report.passed -eq $true -and $case.Process.ExitCode -eq 0 -and $errors.Count -eq 0
        $allPassed = $allPassed -and $passed
        $summaries += [pscustomobject]@{ name = $case.Name; passed = $passed; exit_code = $case.Process.ExitCode; errors = $errors.Count; report = $report }
        Write-Host ("{0}: passed={1}, exit={2}" -f $case.Name, $passed, $case.Process.ExitCode)
        if (-not $passed) {
            if (Test-Path -LiteralPath $case.Stdout) { Get-Content -LiteralPath $case.Stdout -Tail 8 | Write-Host }
            if (Test-Path -LiteralPath $case.Stderr) { Get-Content -LiteralPath $case.Stderr -Tail 16 | Write-Host }
        }
    }
    [pscustomobject]@{ passed = $allPassed; clients = $Clients; duration = $Duration; cases = $summaries } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $resultDirectory 'summary.json') -Encoding UTF8
    Write-Host "Reports: $resultDirectory"
    if (-not $allPassed) { exit 1 }
} finally {
    # No process enumeration: only exact children created by this invocation.
    foreach ($case in $cases) {
        if (-not $case.Process.HasExited) { Stop-Process -Id $case.Process.Id -Force -ErrorAction SilentlyContinue }
    }
}
