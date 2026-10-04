[CmdletBinding()]
param([switch]$Templates, [switch]$WebTemplates)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$version = '4.7.2'
$runtimeDirectory = Join-Path $PSScriptRoot 'runtime'
$releaseBase = "https://github.com/godotengine/godot-builds/releases/download/$version-stable"
New-Item -ItemType Directory -Path $runtimeDirectory -Force | Out-Null
$checksumPath = Join-Path $runtimeDirectory 'SHA512-SUMS.txt'
if (-not (Test-Path -LiteralPath $checksumPath)) {
    Invoke-WebRequest -UseBasicParsing -Uri "$releaseBase/SHA512-SUMS.txt" -OutFile $checksumPath
}

function Get-VerifiedArchive([string]$Name) {
    $archivePath = Join-Path $runtimeDirectory $Name
    if (-not (Test-Path -LiteralPath $archivePath)) {
        Write-Host "Downloading official Godot archive: $Name"
        $temporaryPath = "$archivePath.download"
        Invoke-WebRequest -UseBasicParsing -Uri "$releaseBase/$Name" -OutFile $temporaryPath
        Move-Item -LiteralPath $temporaryPath -Destination $archivePath -Force
    }
    $checksumLines = @(Get-Content -LiteralPath $checksumPath | Where-Object { $_ -match ([regex]::Escape($Name) + '$') })
    if ($checksumLines.Count -ne 1) { throw "Missing or ambiguous official checksum: $Name" }
    $expectedHash = ($checksumLines[0] -split '\s+')[0]
    $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA512).Hash
    if ($actualHash -ne $expectedHash) { throw "SHA512 verification failed for $Name. Remove this archive and retry." }
    Write-Host "Official SHA512 verified: $Name"
    return $archivePath
}

$enginePath = Join-Path $runtimeDirectory "Godot_v$version-stable_win64_console.exe"
if (-not (Test-Path -LiteralPath $enginePath)) {
    $editorArchive = Get-VerifiedArchive "Godot_v$version-stable_win64.exe.zip"
    Expand-Archive -LiteralPath $editorArchive -DestinationPath $runtimeDirectory -Force
}
# Self-contained mode keeps editor settings and templates out of the user profile.
New-Item -ItemType File -Path (Join-Path $runtimeDirectory '_sc_') -Force | Out-Null

if ($Templates -or $WebTemplates) {
    $templateDirectory = Join-Path $runtimeDirectory 'templates'
    $templateNames = @()
    if ($Templates) { $templateNames += @('windows_release_x86_64.exe', 'windows_debug_x86_64.exe') }
    if ($WebTemplates) { $templateNames += @('web_nothreads_release.zip', 'web_nothreads_debug.zip') }
    $missing = @($templateNames | Where-Object { -not (Test-Path -LiteralPath (Join-Path $templateDirectory $_)) })
    if ($missing.Count -gt 0) {
        $templateArchive = Get-VerifiedArchive "Godot_v$version-stable_export_templates.tpz"
        New-Item -ItemType Directory -Path $templateDirectory -Force | Out-Null
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [IO.Compression.ZipFile]::OpenRead($templateArchive)
        try {
            foreach ($templateName in $missing) {
                $entry = $zip.GetEntry("templates/$templateName")
                if ($null -eq $entry) { throw "Official archive lacks templates/$templateName" }
                [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $templateDirectory $templateName), $true)
            }
        } finally { $zip.Dispose() }
    }
}
& $enginePath --version
if ($LASTEXITCODE -ne 0) { throw 'Godot executable verification failed.' }
Write-Host "Portable runtime ready: $runtimeDirectory"
