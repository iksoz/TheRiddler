[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ProfilePath,

    [Parameter(Mandatory)]
    [string]$AllowedUserNameCsv,

    [Parameter(Mandatory)]
    [string]$ForbiddenUserNameCsv
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$Ansible.Changed = $false

$resolvedProfile = [IO.Path]::GetFullPath($ProfilePath)
$usersRoot = [IO.Path]::GetFullPath((Join-Path $env:SystemDrive 'Users'))
$usersPrefix = $usersRoot.TrimEnd('\') + '\'

if (-not $resolvedProfile.StartsWith($usersPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Profile '$resolvedProfile' is outside the per-user profile root '$usersRoot'."
}

$relativePath = $resolvedProfile.Substring($usersPrefix.Length)
$segments = $relativePath.Split([char]'\')
if ($segments.Count -lt 2 -or [string]::IsNullOrWhiteSpace($segments[0])) {
    throw "Profile '$resolvedProfile' does not identify a specific Windows user."
}

$profileUser = $segments[0]
$allowedUserNames = @($AllowedUserNameCsv.Split(';') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$isAllowed = @($allowedUserNames | Where-Object {
    $profileUser -ieq $_ -or $profileUser -ilike ($_ + '.*')
}).Count -gt 0
if (-not $isAllowed) {
    throw "Profile user '$profileUser' is not in the packet-declared Blue Team account allowlist."
}

$forbiddenUserNames = @($ForbiddenUserNameCsv.Split(';') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$isForbidden = @($forbiddenUserNames | Where-Object {
    $profileUser -ieq $_ -or $profileUser -ilike ($_ + '.*')
}).Count -gt 0
if ($isForbidden) {
    throw "Refusing to modify the off-limits account '$profileUser'."
}

$userHome = Join-Path $usersRoot $profileUser
if (-not (Test-Path -LiteralPath $userHome -PathType Container)) {
    throw "User profile directory '$userHome' does not exist. Supply an exact, existing profile path."
}

if ([IO.Path]::GetFileName($resolvedProfile) -ne 'Microsoft.PowerShell_profile.ps1') {
    throw "Profile '$resolvedProfile' is not an interactive Microsoft.PowerShell profile."
}

$profileEditionDirectory = Split-Path (Split-Path $resolvedProfile -Parent) -Leaf
if ($profileEditionDirectory -notin @('WindowsPowerShell', 'PowerShell')) {
    throw "Profile '$resolvedProfile' is outside a Windows PowerShell or PowerShell profile directory."
}

$Ansible.Result = @{
    profilePath = $resolvedProfile
    profileUser = $profileUser
    validated = $true
}
