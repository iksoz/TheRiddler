[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$InstallRoot
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$Ansible.Changed = $false

$destination = [IO.Path]::GetFullPath($InstallRoot)
$driveRoot = [IO.Path]::GetPathRoot($destination)
$programData = [IO.Path]::GetFullPath($env:ProgramData)

if ($destination -eq $driveRoot -or $destination -eq $programData -or
    $destination.Length -lt ($driveRoot.Length + 4)) {
    throw "Unsafe TheRiddler install root '$destination'."
}

$markerPath = Join-Path $destination '.theriddler-install.json'
if (Test-Path -LiteralPath $destination -PathType Container) {
    $items = @(Get-ChildItem -LiteralPath $destination -Force)
    if ($items.Count -gt 0) {
        if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
            throw "Install root '$destination' is not empty and has no TheRiddler ownership marker."
        }

        $marker = Get-Content -LiteralPath $markerPath -Raw | ConvertFrom-Json
        if ($marker.product -ne 'TheRiddler') {
            throw "Install root '$destination' has a foreign or invalid ownership marker."
        }
    }
}

$Ansible.Result = @{
    installRoot = $destination
    validated = $true
}
