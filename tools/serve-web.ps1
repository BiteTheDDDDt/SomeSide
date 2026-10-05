[CmdletBinding()]
param(
    [string]$Directory = '',
    [ValidateRange(0, 65535)][int]$Port = 8765,
    [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'
$projectDirectory = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if (-not $Directory) {
    $version = [regex]::Match((Get-Content -LiteralPath (Join-Path $projectDirectory 'project.godot') -Raw), 'config/version="([^"]+)"').Groups[1].Value
    if (-not $version) { throw 'Missing project version.' }
    $Directory = Join-Path $projectDirectory "dist\v$version-web"
}
if (-not (Test-Path -LiteralPath (Join-Path $Directory 'index.html'))) {
    throw 'Web export is missing. Run tools/run.ps1 -Mode ExportWeb first.'
}
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { throw 'Python 3 is required for local preview. itch.io players do not need Python.' }
$previewArguments = @((Join-Path $PSScriptRoot 'preview_web.py'), $Directory, '--port', "$Port")
if ($NoBrowser) { $previewArguments += '--no-browser' }
& $python.Source @previewArguments
exit $LASTEXITCODE
