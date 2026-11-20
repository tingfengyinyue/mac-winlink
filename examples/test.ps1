$ErrorActionPreference = 'Stop'
Write-Output ("Testing on " + $env:COMPUTERNAME)
Get-Location
# Example for a Node project configured with --workdir:
# npm.cmd test
# exit $LASTEXITCODE
