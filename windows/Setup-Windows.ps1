#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$RequestFile,
    [ValidatePattern('^[a-zA-Z0-9_][a-zA-Z0-9_.-]*$')][string]$User = $env:USERNAME,
    [ValidateRange(1, 65535)][int]$Port = 22,
    [switch]$AllowSharedAdministratorKey,
    [switch]$SkipServerInstall,
    [switch]$ValidateOnly
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
if (!$RequestFile) {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = 'Select the pairing file created on your Mac'
    $dialog.Filter = 'WinLink pairing (*.winlink.json)|*.winlink.json'
    if ($dialog.ShowDialog() -ne 'OK') { throw 'No pairing file selected.' }
    $RequestFile = $dialog.FileName
}
$RequestFile = (Resolve-Path -LiteralPath $RequestFile).Path
$request = [IO.File]::ReadAllText($RequestFile) | ConvertFrom-Json
if ($request.schemaVersion -ne 1 -or $request.kind -notin @('winlink-request', 'winlink-connection')) {
    throw 'Unsupported pairing file. Run setup.sh prepare on the Mac first.'
}
if ($request.name -cnotmatch '^[a-zA-Z0-9][a-zA-Z0-9_-]*$') { throw 'Invalid target name.' }
$client = $null
if (![Net.IPAddress]::TryParse([string]$request.clientAddress, [ref]$client) -or
    $client.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork -or
    [Net.IPAddress]::IsLoopback($client) -or $client.Equals([Net.IPAddress]::Any) -or
    $client.Equals([Net.IPAddress]::Broadcast)) { throw 'Pairing file must contain a single reachable Mac IPv4 address.' }
if ($request.publicKey -cnotmatch '^ssh-ed25519 [A-Za-z0-9+/]+={0,3}(?: [^\r\n]*)?$') {
    throw 'Pairing file must contain one Ed25519 PUBLIC key.'
}
if ($request.clientKeyFingerprint -cnotmatch '^SHA256:[A-Za-z0-9+/]{43}$') { throw 'Invalid Mac key fingerprint.' }
$blob = [Convert]::FromBase64String(($request.publicKey -split ' ', 3)[1])
if ($blob.Length -ne 51 -or [Text.Encoding]::ASCII.GetString($blob, 4, 11) -cne 'ssh-ed25519' -or
    $blob[0] -ne 0 -or $blob[1] -ne 0 -or $blob[2] -ne 0 -or $blob[3] -ne 11 -or
    $blob[15] -ne 0 -or $blob[16] -ne 0 -or $blob[17] -ne 0 -or $blob[18] -ne 32) {
    throw 'Invalid Ed25519 public key encoding.'
}
$sha = [Security.Cryptography.SHA256]::Create()
try { $calculated = 'SHA256:' + [Convert]::ToBase64String($sha.ComputeHash($blob)).TrimEnd('=') }
finally { $sha.Dispose() }
if ($calculated -cne $request.clientKeyFingerprint) { throw 'Mac public key does not match its pairing fingerprint.' }
$principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
$isElevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (!$isElevated -and !$ValidateOnly) {
    $ps = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    # Windows paths cannot contain a quote; use explicit quoted arguments for spaces.
    $arguments = @('-NoProfile', '-NoExit', '-ExecutionPolicy', 'Bypass', '-File',
        ('"{0}"' -f $PSCommandPath), '-RequestFile', ('"{0}"' -f $RequestFile),
        '-User', ('"{0}"' -f $User), '-Port', $Port)
    if ($AllowSharedAdministratorKey) { $arguments += '-AllowSharedAdministratorKey' }
    if ($SkipServerInstall) { $arguments += '-SkipServerInstall' }
    Write-Host 'Opening an administrator window. Continue in the NEW window and approve the Windows UAC prompt.'
    $elevated = Start-Process -FilePath $ps -ArgumentList $arguments -Verb RunAs -PassThru -Wait
    exit $elevated.ExitCode
}
$account = Get-LocalUser -Name $User
if (!$account.Enabled) { throw 'The selected local Windows account is disabled.' }
$adminSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
$isAdmin = @(Get-LocalGroupMember -SID $adminSid | Where-Object { $_.SID -eq $account.SID }).Count -gt 0
if ($ValidateOnly) {
    [ordered]@{ name = $request.name; clientAddress = $client.ToString(); user = $User;
        port = $Port; administratorAccount = $isAdmin; elevated = $isElevated } | ConvertTo-Json
    exit 0
}
if ($isAdmin -and !$AllowSharedAdministratorKey) {
    Write-Warning 'Windows administrators share administrators_authorized_keys. This key may log in to other administrator accounts.'
    if ((Read-Host 'Type YES to use this administrator account, or cancel and choose a standard account') -cne 'YES') {
        throw 'Administrator shared-key authorization was not accepted.'
    }
    $AllowSharedAdministratorKey = $true
}
$logDir = Join-Path $env:LOCALAPPDATA 'WinLink\logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$log = Join-Path $logDir ('setup-' + [DateTime]::Now.ToString('yyyyMMdd-HHmmssfff') + '.log')
$keyFile = $null
Start-Transcript -Path $log | Out-Null
try {
    if (!$SkipServerInstall) {
        Write-Host '[1/4] Installing/configuring OpenSSH. First installation may take several minutes.'
        & (Join-Path $PSScriptRoot 'Install-WinLink.ps1') -Port $Port `
            -RemoteAddress $client.ToString() -NetworkProfile @('Private', 'Domain', 'Public')
        if (!$?) { throw 'OpenSSH setup failed.' }
    } else {
        Write-Host '[1/4] Using the existing running SSH server (no restart).'
        if ((Get-Service sshd).Status -ne 'Running') { throw 'Existing SSH server is not running.' }
        if (!(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)) { throw 'SSH port is not listening.' }
    }
    $keygen = Join-Path $env:WINDIR 'System32\OpenSSH\ssh-keygen.exe'
    $keyFile = [IO.Path]::GetTempFileName()
    [IO.File]::WriteAllText($keyFile, $request.publicKey.Trim() + "`n", [Text.UTF8Encoding]::new($false))
    $macFingerprint = (& $keygen -lf $keyFile)
    if ($LASTEXITCODE -ne 0 -or ($macFingerprint -split '\s+')[1] -cne $request.clientKeyFingerprint) {
        throw 'Mac public key does not match its pairing fingerprint.'
    }
    Write-Host '[2/4] Authorizing the Mac public key.'
    $auth = @{ User = $User; PublicKeyFile = $keyFile }
    if ($AllowSharedAdministratorKey) { $auth.AllowSharedAdministratorKey = $true }
    & (Join-Path $PSScriptRoot 'Authorize-Mac.ps1') @auth
    if (!$?) { throw 'Public-key authorization failed.' }
    Write-Host '[3/4] Allowing SSH only from the selected Mac on all network profiles.'
    $suffix = ($request.clientKeyFingerprint -replace '[^A-Za-z0-9]', '')
    $ruleName = 'WinLink-Client-' + $suffix.Substring($suffix.Length - 12)
    if (Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue) {
        Set-NetFirewallRule -Name $ruleName -Enabled True -Direction Inbound -Action Allow `
            -Protocol TCP -LocalPort $Port -RemoteAddress $client.ToString() -Profile Any | Out-Null
    } else {
        New-NetFirewallRule -Name $ruleName -DisplayName 'WinLink paired Mac SSH' -Enabled True `
            -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port `
            -RemoteAddress $client.ToString() -Profile Any | Out-Null
    }
    # Routing selects the local address used to reach this Mac, not an arbitrary adapter.
    $socket = [Net.Sockets.Socket]::new([Net.Sockets.AddressFamily]::InterNetwork,
        [Net.Sockets.SocketType]::Dgram, [Net.Sockets.ProtocolType]::Udp)
    try { $socket.Connect($client, $Port); $hostAddress = $socket.LocalEndPoint.Address.ToString() }
    finally { $socket.Dispose() }
    $hostKey = Join-Path $env:ProgramData 'ssh\ssh_host_ed25519_key.pub'
    $hostFingerprint = (& $keygen -lf $hostKey)
    if ($LASTEXITCODE -ne 0) { throw 'Could not read Windows SSH host fingerprint.' }
    $connection = [ordered]@{
        schemaVersion = 1; kind = 'winlink-connection'; name = $request.name
        clientAddress = $client.ToString(); publicKey = $request.publicKey
        clientKeyFingerprint = $request.clientKeyFingerprint
        hostAddress = $hostAddress; hostFingerprint = ($hostFingerprint -split '\s+')[1]
        user = $User; port = $Port; firewallRule = $ruleName
    }
    Write-Host '[4/4] Writing the connection file for your Mac.'
    $next = $RequestFile + '.new'
    [IO.File]::WriteAllText($next, ($connection | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $next -Destination $RequestFile -Force
    Write-Host "READY: $RequestFile"
    Write-Host 'Copy this UPDATED file back to the Mac. Run: bash setup.sh connect <file.winlink.json>'
    Write-Host "Local setup log: $log"
} catch {
    Write-Host "SETUP FAILED: $($_.Exception.Message)"
    Write-Host "Local setup log: $log"
    throw
} finally {
    if ($keyFile -and (Test-Path -LiteralPath $keyFile)) { Remove-Item -LiteralPath $keyFile -Force }
    Stop-Transcript | Out-Null
}
