[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)]
    [string]$InstallRoot
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$Ansible.Changed = $false

$destination = [IO.Path]::GetFullPath($InstallRoot)
if (-not (Test-Path -LiteralPath $destination)) {
    $Ansible.Result = @{ installRoot = $destination; state = 'Absent' }
    return
}

$driveRoot = [IO.Path]::GetPathRoot($destination)
$programData = [IO.Path]::GetFullPath($env:ProgramData)
if ($destination -eq $driveRoot -or $destination -eq $programData -or
    $destination.Length -lt ($driveRoot.Length + 4)) {
    throw "Refusing to remove unsafe install root '$destination'."
}

$markerPath = Join-Path $destination '.theriddler-install.json'
if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
    throw "Refusing to remove '$destination' because it has no ownership marker."
}

$marker = Get-Content -LiteralPath $markerPath -Raw | ConvertFrom-Json
if ($marker.product -ne 'TheRiddler') {
    throw "Refusing to remove '$destination' because its ownership marker is invalid."
}

$Ansible.Changed = $true
if ($PSCmdlet.ShouldProcess($destination, 'Remove TheRiddler installation')) {
    Remove-Item -LiteralPath $destination -Recurse -Force
}

$Ansible.Result = @{ installRoot = $destination; state = 'Absent' }
