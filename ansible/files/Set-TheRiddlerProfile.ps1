[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ProfilePath,

    [Parameter(Mandatory)]
    [ValidateSet('Present', 'Absent')]
    [string]$State,

    [Parameter()]
    [string]$ManifestPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$Ansible.Changed = $false

$resolvedProfile = [IO.Path]::GetFullPath($ProfilePath)
$startMarker = '# >>> TheRiddler managed block >>>'
$endMarker = '# <<< TheRiddler managed block <<<'
$startPattern = '(?m)^' + [regex]::Escape($startMarker) + '\r?$'
$endPattern = '(?m)^' + [regex]::Escape($endMarker) + '\r?$'
$blockPattern = '(?ms)^' + [regex]::Escape($startMarker) +
    '\r?\n.*?^' + [regex]::Escape($endMarker) + '\r?(?:\n|$)'

$existing = if (Test-Path -LiteralPath $resolvedProfile -PathType Leaf) {
    [IO.File]::ReadAllText($resolvedProfile)
} else {
    ''
}

$startCount = [regex]::Matches($existing, $startPattern).Count
$endCount = [regex]::Matches($existing, $endPattern).Count
if ($startCount -ne $endCount -or $startCount -gt 1) {
    throw "Profile '$resolvedProfile' contains malformed or duplicate TheRiddler markers."
}

if ($State -eq 'Present') {
    if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
        throw 'ManifestPath is required when State is Present.'
    }

    $resolvedManifest = [IO.Path]::GetFullPath($ManifestPath)
    $escapedManifest = $resolvedManifest.Replace("'", "''")
    $managedBlock = @"
$startMarker
if (`$Host.Name -eq 'ConsoleHost' -and [Environment]::UserInteractive) {
    try {
        Import-Module '$escapedManifest' -Force
        Enter-TheRiddlerShell
    }
    finally {
        [Environment]::Exit(0)
    }
}
$endMarker
"@

    if ($startCount -eq 1) {
        $blockRegex = [regex]::new($blockPattern)
        $replacement = ($managedBlock + "`r`n").Replace('$', '$$')
        $updated = $blockRegex.Replace($existing, $replacement, 1)
    } else {
        $separator = if ([string]::IsNullOrEmpty($existing) -or $existing.EndsWith("`n")) {
            ''
        } else {
            "`r`n"
        }
        $updated = $existing + $separator + $managedBlock + "`r`n"
    }
} else {
    if ($startCount -eq 0) {
        $Ansible.Result = @{ profilePath = $resolvedProfile; state = 'Absent' }
        return
    }
    $blockRegex = [regex]::new($blockPattern)
    $updated = $blockRegex.Replace($existing, '', 1)
}

if ($updated -ne $existing) {
    $Ansible.Changed = $true
    if ($PSCmdlet.ShouldProcess($resolvedProfile, "Set TheRiddler profile state to $State")) {
        $profileDirectory = Split-Path $resolvedProfile -Parent
        New-Item -ItemType Directory -Path $profileDirectory -Force | Out-Null
        [IO.File]::WriteAllText($resolvedProfile, $updated, [Text.UTF8Encoding]::new($true))
    }
}

$Ansible.Result = @{
    profilePath = $resolvedProfile
    state = $State
}
