<#
.SYNOPSIS
Installs TheRiddler runtime files and optionally activates an interactive profile.
.DESCRIPTION
Copies only the module and riddle inventory into InstallRoot. When EnableProfile is
specified, appends one clearly marked startup block to the exact ProfilePath. Existing
non-TheRiddler profile content is preserved, and duplicate managed blocks are rejected.
.PARAMETER SourceRoot
Root of a complete TheRiddler checkout or staged runtime payload.
.PARAMETER InstallRoot
Destination for the managed runtime and its ownership marker.
.PARAMETER ProfilePath
Exact interactive user's PowerShell profile to update.
.PARAMETER EnableProfile
Adds the managed startup block. Without this switch, only runtime files are refreshed.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$SourceRoot = (Split-Path $PSScriptRoot -Parent),

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$InstallRoot,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ProfilePath,

    [Parameter()]
    [switch]$EnableProfile
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# Normalize paths once so validation and writes refer to the same locations.
$source = [IO.Path]::GetFullPath($SourceRoot)
$destination = [IO.Path]::GetFullPath($InstallRoot)
$moduleSource = Join-Path $source 'src\TheRiddler'
$inventorySource = Join-Path $source 'inventory\riddles.json'
$installMarker = Join-Path $destination '.theriddler-install.json'

if (-not (Test-Path -LiteralPath (Join-Path $moduleSource 'TheRiddler.psd1') -PathType Leaf) -or
    -not (Test-Path -LiteralPath $inventorySource -PathType Leaf)) {
    throw "SourceRoot '$source' does not contain a complete TheRiddler checkout."
}

if ($EnableProfile -and [string]::IsNullOrWhiteSpace($ProfilePath)) {
    throw '-ProfilePath is required when -EnableProfile is used.'
}

# A non-empty unmarked directory may belong to another application; never adopt it.
if (Test-Path -LiteralPath $destination -PathType Container) {
    $existingItems = @(Get-ChildItem -LiteralPath $destination -Force)
    if ($existingItems.Count -gt 0 -and -not (Test-Path -LiteralPath $installMarker -PathType Leaf)) {
        throw "InstallRoot '$destination' is not empty and is not marked as a TheRiddler installation."
    }
}

# The marker records ownership for the uninstaller. It is written only after the
# required runtime files have been copied successfully.
if ($PSCmdlet.ShouldProcess($destination, 'Install TheRiddler files')) {
    New-Item -ItemType Directory -Path (Join-Path $destination 'src\TheRiddler') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $destination 'inventory') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $moduleSource 'TheRiddler.psd1') -Destination (Join-Path $destination 'src\TheRiddler\TheRiddler.psd1') -Force
    Copy-Item -LiteralPath (Join-Path $moduleSource 'TheRiddler.psm1') -Destination (Join-Path $destination 'src\TheRiddler\TheRiddler.psm1') -Force
    Copy-Item -LiteralPath $inventorySource -Destination (Join-Path $destination 'inventory\riddles.json') -Force
    $marker = [ordered]@{
        product = 'TheRiddler'
        version = '1.0.0'
        installedUtc = [DateTimeOffset]::UtcNow.ToString('O')
    } | ConvertTo-Json
    Set-Content -LiteralPath $installMarker -Value $marker -Encoding UTF8
}

if ($EnableProfile) {
    $resolvedProfile = [IO.Path]::GetFullPath($ProfilePath)
    $profileDirectory = Split-Path $resolvedProfile -Parent
    $moduleManifest = Join-Path $destination 'src\TheRiddler\TheRiddler.psd1'
    $escapedManifest = $moduleManifest.Replace("'", "''")
    $startMarker = '# >>> TheRiddler managed block >>>'
    $endMarker = '# <<< TheRiddler managed block <<<'
    # ConsoleHost and UserInteractive prevent background or non-interactive PowerShell
    # processes from entering the challenge loop.
    $block = @"
$startMarker
if (`$Host.Name -eq 'ConsoleHost' -and [Environment]::UserInteractive) {
    Import-Module '$escapedManifest' -Force
    Enter-TheRiddlerShell
    exit
}
$endMarker
"@

    $existing = if (Test-Path -LiteralPath $resolvedProfile) {
        Get-Content -LiteralPath $resolvedProfile -Raw
    } else { '' }

    # Refuse duplicates instead of attempting to merge two managed blocks.
    if ($existing -match [regex]::Escape($startMarker)) {
        throw "Profile '$resolvedProfile' already contains a TheRiddler managed block. Uninstall it before reinstalling."
    }

    if ($PSCmdlet.ShouldProcess($resolvedProfile, 'Add TheRiddler interactive startup block')) {
        New-Item -ItemType Directory -Path $profileDirectory -Force | Out-Null
        $prefix = if ([string]::IsNullOrEmpty($existing) -or $existing.EndsWith("`n")) { '' } else { "`r`n" }
        Add-Content -LiteralPath $resolvedProfile -Value ($prefix + $block) -Encoding UTF8
    }
}

Write-Output "TheRiddler installed at '$destination'."

