[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$CoverSource,
    [string]$OutputDirectory = '',
    [ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version = '',
    [ValidatePattern('^[A-Za-z0-9_-]+$')][string]$CoverStem = 'SomeSide-cover'
)

$ErrorActionPreference = 'Stop'
$projectDirectory = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if (-not $Version) {
    $projectText = Get-Content -LiteralPath (Join-Path $projectDirectory 'project.godot') -Raw
    $Version = [regex]::Match($projectText, '(?m)^config/version="(\d+\.\d+\.\d+)"').Groups[1].Value
    if (-not $Version) { throw 'project.godot must declare a valid version.' }
}
if (-not $OutputDirectory) { $OutputDirectory = "marketing/v$Version" }
$sourcePath = (Resolve-Path -LiteralPath $CoverSource).Path
$outputPath = [IO.Path]::GetFullPath((Join-Path $projectDirectory $OutputDirectory))
if (-not $outputPath.StartsWith($projectDirectory + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Promotional output must stay inside this project.'
}
$coverDirectory = Join-Path $outputPath 'covers'
New-Item -ItemType Directory -Path $coverDirectory -Force | Out-Null
Add-Type -AssemblyName System.Drawing

# Technical size exports only. Creative retouching is performed with imagegen;
# gameplay screenshots are copied byte-for-byte from the Godot capture output.
$sourceImage = [Drawing.Image]::FromFile($sourcePath)
try {
    if ([Math]::Abs(($sourceImage.Width / $sourceImage.Height) / (630.0 / 500.0) - 1.0) -gt 0.015) {
        throw 'Cover aspect ratio must already match 63:50; no automatic crop is applied.'
    }
    foreach ($size in @(@(630, 500), @(315, 250))) {
        $bitmap = New-Object Drawing.Bitmap($size[0], $size[1])
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
            $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.DrawImage($sourceImage, 0, 0, $size[0], $size[1])
            $bitmap.Save((Join-Path $coverDirectory "$CoverStem-$($size[0])x$($size[1]).png"), [Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $graphics.Dispose()
            $bitmap.Dispose()
        }
    }
} finally {
    $sourceImage.Dispose()
}

$masterPath = Join-Path $coverDirectory "$CoverStem-master.png"
if ($sourcePath -ne $masterPath) { Copy-Item -LiteralPath $sourcePath -Destination $masterPath -Force }
$coverFiles = @('315x250', '630x500', 'master') | ForEach-Object { Join-Path $coverDirectory "$CoverStem-$_.png" }
$imageFiles = @($coverFiles) + @(Get-ChildItem -LiteralPath (Join-Path $outputPath 'screenshots') -File -Filter '*.png' | ForEach-Object FullName)
$manifest = @(Get-Item -LiteralPath $imageFiles | Sort-Object FullName | ForEach-Object {
    $picture = [Drawing.Image]::FromFile($_.FullName)
    try {
        [ordered]@{
            file = $_.FullName.Substring($outputPath.Length + 1).Replace('\', '/')
            width = $picture.Width
            height = $picture.Height
            bytes = $_.Length
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    } finally { $picture.Dispose() }
})
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $outputPath 'files.json') -Encoding UTF8
$packagePath = Join-Path $projectDirectory "dist/SomeSide-v$Version-press-images.zip"
$packageFiles = @($coverFiles) + @((Join-Path $outputPath 'screenshots'), (Join-Path $outputPath 'README.txt'), (Join-Path $outputPath 'files.json'), (Join-Path $outputPath 'index.html'))
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$pendingPath = Join-Path (Split-Path -Parent $packagePath) ([IO.Path]::GetRandomFileName() + '.zip')
$zip = [IO.Compression.ZipFile]::Open($pendingPath, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($packageFile in $packageFiles) {
        $entries = if (Test-Path -LiteralPath $packageFile -PathType Container) {
            Get-ChildItem -LiteralPath $packageFile -File -Recurse
        } else { Get-Item -LiteralPath $packageFile }
        foreach ($entry in $entries) {
            $name = $entry.FullName.Substring($outputPath.Length + 1).Replace('\', '/')
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $entry.FullName, $name, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    }
} finally { $zip.Dispose() }
Move-Item -LiteralPath $pendingPath -Destination $packagePath -Force
Write-Output $packagePath
