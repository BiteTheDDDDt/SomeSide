[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectDirectory = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$distributionDirectory = Join-Path $projectDirectory 'dist\v0.10.0'
$executablePath = Join-Path $distributionDirectory 'SomeSide.exe'
if (-not (Test-Path -LiteralPath $executablePath)) { throw 'Export SomeSide.exe before packaging.' }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'QUICKSTART.zh-CN.txt') -Destination (Join-Path $distributionDirectory 'README.txt') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'licenses\GODOT-LICENSE.txt') -Destination (Join-Path $distributionDirectory 'GODOT-LICENSE.txt') -Force
Copy-Item -LiteralPath (Join-Path $projectDirectory 'assets\fonts\OFL.txt') -Destination (Join-Path $distributionDirectory 'FONT-OFL.txt') -Force
$packagePath = Join-Path $projectDirectory 'dist\SomeSide-v0.10.0-windows-x64.zip'
$packageFiles = @('SomeSide.exe', 'README.txt', 'GODOT-LICENSE.txt', 'FONT-OFL.txt') | ForEach-Object { Join-Path $distributionDirectory $_ }
Compress-Archive -LiteralPath $packageFiles -DestinationPath $packagePath -CompressionLevel Optimal -Force
$manifest = [pscustomobject]@{
    version = '0.10.0'
    engine = '4.7.2.stable.official.ed1daf0bf'
    built_at_utc = [DateTime]::UtcNow.ToString('o')
    executable = $executablePath
    executable_bytes = (Get-Item -LiteralPath $executablePath).Length
    executable_sha256 = (Get-FileHash -LiteralPath $executablePath -Algorithm SHA256).Hash
    package = $packagePath
    package_bytes = (Get-Item -LiteralPath $packagePath).Length
    package_sha256 = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash
}
New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot 'results') -Force | Out-Null
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'results\package.json') -Encoding UTF8
$manifest | ConvertTo-Json | Write-Output
