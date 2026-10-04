[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$input = Join-Path $root 'data\demo'
$output = Join-Path $root 'output'
& (Join-Path $PSScriptRoot 'profile-and-clean.ps1') -InputDirectory $input -OutputDirectory $output
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw "Profiling pipeline failed with exit code $LASTEXITCODE"
}
& (Join-Path $PSScriptRoot 'profile-workspace.ps1')
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw "Workspace profiling failed with exit code $LASTEXITCODE"
}
Write-Output 'Workspace profiling complete. Interpret results using output/workspace-data-profile.md and its synthetic-data caveat.'
