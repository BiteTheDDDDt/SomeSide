[CmdletBinding()]
param(
    [ValidateSet('Windows', 'Web')]
    [string]$Platform = 'Windows'
)

$ErrorActionPreference = 'Stop'
$projectDirectory = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$projectText = Get-Content -LiteralPath (Join-Path $projectDirectory 'project.godot') -Raw
$versionMatch = [regex]::Match($projectText, '(?m)^config/version="(\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?)"\s*$')
if (-not $versionMatch.Success) { throw 'project.godot must declare a valid config/version.' }
$version = $versionMatch.Groups[1].Value
$distributionName = if ($Platform -eq 'Web') { "v$version-web" } else { "v$version" }
$distributionDirectory = Join-Path (Join-Path $projectDirectory 'dist') $distributionName
$executablePath = Join-Path $distributionDirectory 'SomeSide.exe'
if ($Platform -eq 'Windows') {
    if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf)) { throw 'Export SomeSide.exe before packaging.' }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'QUICKSTART.zh-CN.txt') -Destination (Join-Path $distributionDirectory 'README.txt') -Force
} else {
    foreach ($required in @('index.html', 'index.js', 'index.wasm', 'index.pck')) {
        if (-not (Test-Path -LiteralPath (Join-Path $distributionDirectory $required) -PathType Leaf)) {
            throw "Export the Web build before packaging: missing $required."
        }
    }
    $nativeFiles = @(Get-ChildItem -LiteralPath $distributionDirectory -File -Recurse -Force | Where-Object { $_.Extension -in @('.exe', '.dll', '.pdb', '.so', '.dylib', '.cmd', '.bat') })
    if ($nativeFiles.Count -gt 0) { throw "Native artifacts found in Web export: $($nativeFiles.Name -join ', ')" }
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'licenses\GODOT-LICENSE.txt') -Destination (Join-Path $distributionDirectory 'GODOT-LICENSE.txt') -Force
Copy-Item -LiteralPath (Join-Path $projectDirectory 'assets\fonts\OFL.txt') -Destination (Join-Path $distributionDirectory 'FONT-OFL.txt') -Force
$packageSuffix = if ($Platform -eq 'Web') { 'web' } else { 'windows-x64' }
$packagePath = Join-Path $projectDirectory "dist\SomeSide-v$version-$packageSuffix.zip"
if ($Platform -eq 'Windows') {
    $packageFiles = @('SomeSide.exe', 'README.txt', 'GODOT-LICENSE.txt', 'FONT-OFL.txt') | ForEach-Object { Join-Path $distributionDirectory $_ }
    Compress-Archive -LiteralPath $packageFiles -DestinationPath $packagePath -CompressionLevel Optimal -Force
} else {
    # Include every exported file, including nested/hidden assets, without an
    # outer v*-web directory. itch.io loads the root-level index.html.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $pendingPath = Join-Path (Split-Path -Parent $packagePath) ([System.IO.Path]::GetRandomFileName() + '.zip')
    try {
        [System.IO.Compression.ZipFile]::CreateFromDirectory($distributionDirectory, $pendingPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)
        Move-Item -LiteralPath $pendingPath -Destination $packagePath -Force
    } finally {
        if (Test-Path -LiteralPath $pendingPath -PathType Leaf) { Remove-Item -LiteralPath $pendingPath -Force }
    }
}
$manifest = [ordered]@{
    version = $version
    engine = '4.7.2.stable.official.ed1daf0bf'
    built_at_utc = [DateTime]::UtcNow.ToString('o')
    package = $packagePath
    package_bytes = (Get-Item -LiteralPath $packagePath).Length
    package_sha256 = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash
}
if ($Platform -eq 'Windows') {
    $manifest.executable = $executablePath
    $manifest.executable_bytes = (Get-Item -LiteralPath $executablePath).Length
    $manifest.executable_sha256 = (Get-FileHash -LiteralPath $executablePath -Algorithm SHA256).Hash
} else {
    $manifest.platform = 'Web'
    $manifest.directory = $distributionDirectory
    $manifest.entrypoint = 'index.html'
    $manifest.files = @(Get-ChildItem -LiteralPath $distributionDirectory -File -Recurse -Force | Sort-Object FullName | ForEach-Object {
        [pscustomobject]@{
            name = $_.FullName.Substring($distributionDirectory.Length + 1).Replace('\', '/')
            bytes = $_.Length
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    })
    $manifest.file_count = $manifest.files.Count
    $manifest.uncompressed_bytes = ($manifest.files | Measure-Object -Property bytes -Sum).Sum
}
$manifestName = if ($Platform -eq 'Web') { 'package-web.json' } else { 'package.json' }
New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot 'results') -Force | Out-Null
$manifestJson = $manifest | ConvertTo-Json -Depth 5
$manifestJson | Set-Content -LiteralPath (Join-Path (Join-Path $PSScriptRoot 'results') $manifestName) -Encoding UTF8
$manifestJson | Write-Output
