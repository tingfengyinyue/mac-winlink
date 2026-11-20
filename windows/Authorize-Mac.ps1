#Requires -Version 5.1
#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidatePattern('^[a-zA-Z0-9_][a-zA-Z0-9_.-]*$')]
    [string]$User,
    [Parameter(Mandatory = $true)][string]$PublicKeyFile,
    [switch]$AllowSharedAdministratorKey,
    [switch]$Revoke
)
$ErrorActionPreference = 'Stop'
$account = Get-LocalUser -Name $User
if (!$account.Enabled) { throw "Local account is disabled: $User" }
$key = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $PublicKeyFile).Path).Trim()
if ($key -notmatch '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(?:256|384|521)) [A-Za-z0-9+/]+={0,3}(?: [^\r\n]*)?$') {
    throw 'Provide a single OpenSSH PUBLIC key (.pub), not a private key or authorized_keys options.'
}
$keygen = Join-Path $env:WINDIR 'System32\OpenSSH\ssh-keygen.exe'
& $keygen -lf $PublicKeyFile
if ($LASTEXITCODE -ne 0) { throw 'Invalid public key.' }
$keyParts = $key -split ' ', 3
$keyId = $keyParts[0] + ' ' + $keyParts[1]
$adminGroupSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
$systemSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-18')
$isAdmin = @(Get-LocalGroupMember -SID $adminGroupSid | Where-Object { $_.SID -eq $account.SID }).Count -gt 0
if ($isAdmin) {
    if (!$AllowSharedAdministratorKey) {
        throw 'This is an administrator account. Windows uses one SHARED key file for administrators. Prefer a standard local account, or explicitly pass -AllowSharedAdministratorKey.'
    }
    Write-Warning 'This key grants SSH access to administrator accounts using the shared administrators_authorized_keys file.'
    $directory = Join-Path $env:ProgramData 'ssh'
    $file = Join-Path $directory 'administrators_authorized_keys'
    $allowedSids = @($adminGroupSid, $systemSid)
} else {
    $profileKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$($account.SID.Value)"
    if (!(Test-Path -LiteralPath $profileKey)) { throw 'Sign in to this Windows account once to create its user profile, then retry.' }
    $profilePath = [Environment]::ExpandEnvironmentVariables((Get-ItemProperty -LiteralPath $profileKey).ProfileImagePath)
    $directory = Join-Path $profilePath '.ssh'
    $file = Join-Path $directory 'authorized_keys'
    $allowedSids = @($account.SID, $adminGroupSid, $systemSid)
    if (!(Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory | Out-Null }
    $dirAcl = [Security.AccessControl.DirectorySecurity]::new()
    $dirAcl.SetAccessRuleProtection($true, $false)
    foreach ($sid in $allowedSids) {
        $rule = [Security.AccessControl.FileSystemAccessRule]::new($sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $dirAcl.AddAccessRule($rule)
    }
    $dirAcl.SetOwner($account.SID)
    Set-Acl -LiteralPath $directory -AclObject $dirAcl
}
if (!(Test-Path -LiteralPath $directory)) { throw 'Install OpenSSH Server first.' }
$existing = @()
if (Test-Path -LiteralPath $file) {
    Copy-Item -LiteralPath $file -Destination "$file.winlink.$([DateTime]::Now.ToString('yyyyMMddHHmmssfff')).bak"
    $existing = @([IO.File]::ReadAllLines($file))
}
$found = $false
$updated = [System.Collections.Generic.List[string]]::new()
foreach ($entry in $existing) {
    $parts = $entry.Trim() -split '\s+', 3
    $sameKey = $parts.Count -ge 2 -and (($parts[0] + ' ' + $parts[1]) -ceq $keyId)
    if ($sameKey) { $found = $true }
    if (!($Revoke -and $sameKey)) { $updated.Add($entry) }
}
if (!$Revoke -and !$found) { $updated.Add($key) }
[IO.File]::WriteAllLines($file, $updated, [Text.UTF8Encoding]::new($false))
$acl = [Security.AccessControl.FileSecurity]::new()
$acl.SetAccessRuleProtection($true, $false)
foreach ($sid in $allowedSids) {
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid, 'FullControl', 'Allow'))
}
if ($isAdmin) { $acl.SetOwner($adminGroupSid) } else { $acl.SetOwner($account.SID) }
Set-Acl -LiteralPath $file -AclObject $acl
if ($Revoke) { Write-Host "Key revoked in $file (other copies with authorized_keys options must be reviewed manually)." }
else { Write-Host "Key authorized in $file. Verify with: winlink doctor <name>" }
Write-Host 'Note: custom sshd_config AuthorizedKeysFile/Match rules must match the standard Windows layout.'
