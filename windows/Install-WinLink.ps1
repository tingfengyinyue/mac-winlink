#Requires -Version 5.1
#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [ValidateRange(1, 65535)][int]$Port = 22,
    [string[]]$RemoteAddress = @('LocalSubnet'),
    [ValidateSet('Private', 'Domain', 'Public')]
    [string[]]$NetworkProfile = @('Private', 'Domain')
)
$ErrorActionPreference = 'Stop'
$capability = Get-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0'
$freshInstall = $capability.State -ne 'Installed'
if ($freshInstall) {
    $result = Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0'
    if ($result.RestartNeeded) { throw 'Restart Windows, then run this script again.' }
}
$openSshDir = Join-Path $env:WINDIR 'System32\OpenSSH'
$sshd = Join-Path $openSshDir 'sshd.exe'
$config = Join-Path $env:ProgramData 'ssh\sshd_config'
if (!(Test-Path -LiteralPath $config)) { Start-Service sshd }
if (!(Test-Path -LiteralPath $config)) { throw "Missing SSH server config: $config" }

# Only change global Port directives; preserve Match blocks and other settings.
$backup = "$config.winlink.$([DateTime]::Now.ToString('yyyyMMddHHmmssfff')).bak"
Copy-Item -LiteralPath $config -Destination $backup
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("Port $Port")
$inMatch = $false
foreach ($line in [IO.File]::ReadAllLines($config)) {
    if ($line -match '^\s*Match\s') { $inMatch = $true }
    if (!$inMatch -and $line -match '^\s*Port\s+') { continue }
    $lines.Add($line)
}
try {
    [IO.File]::WriteAllLines($config, $lines, [Text.UTF8Encoding]::new($false))
    & $sshd -t -f $config
    if ($LASTEXITCODE -ne 0) { throw 'SSH configuration validation failed.' }
    Set-Service -Name sshd -StartupType Automatic
    Restart-Service sshd
} catch {
    Copy-Item -LiteralPath $backup -Destination $config -Force
    try { Restart-Service sshd } catch { Write-Warning $_.Exception.Message }
    throw
}

# Scope the rule we manage. Do not silently change pre-existing administrator rules.
$ruleName = 'WinLink-SSH-In-TCP'
$rule = Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
if ($rule) { Remove-NetFirewallRule -Name $ruleName }
New-NetFirewallRule -Name $ruleName -DisplayName 'WinLink SSH (managed)' `
    -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port `
    -RemoteAddress $RemoteAddress -Profile $NetworkProfile -Enabled True | Out-Null
$builtInRule = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
if ($freshInstall -and $builtInRule) {
    # Setup creates a broader rule. Replace only the rule created during this install.
    Disable-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' | Out-Null
} elseif ($builtInRule -and $builtInRule.Enabled -eq 'True') {
    Write-Warning 'Existing OpenSSH-Server-In-TCP rule is enabled. Its permissions also apply; review its scope separately.'
}
Write-Host "SSH ready on port $Port. Config backup: $backup"
Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
    $_.IPAddress -ne '127.0.0.1' -and $_.AddressState -eq 'Preferred'
} | Select-Object InterfaceAlias, IPAddress
Write-Host 'Compare this host fingerprint with the first SSH connection on each Mac:'
$hostKey = Join-Path $env:ProgramData 'ssh\ssh_host_ed25519_key.pub'
if (Test-Path -LiteralPath $hostKey) {
    & (Join-Path $openSshDir 'ssh-keygen.exe') -lf $hostKey
    if ($LASTEXITCODE -ne 0) { throw 'Could not read host key fingerprint.' }
}
Write-Host 'Next: run Authorize-Mac.ps1 with the Mac PUBLIC key and an existing local Windows user.'
