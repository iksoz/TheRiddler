[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$InstallRoot,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ProfilePath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$destination = [IO.Path]::GetFullPath($InstallRoot)
$installMarker = Join-Path $destination '.theriddler-install.json'
$startMarker = '# >>> TheRiddler managed block >>>'
$endMarker = '# <<< TheRiddler managed block <<<'

if (-not [string]::IsNullOrWhiteSpace($ProfilePath)) {
    $resolvedProfile = [IO.Path]::GetFullPath($ProfilePath)
    if (Test-Path -LiteralPath $resolvedProfile -PathType Leaf) {
        $content = Get-Content -LiteralPath $resolvedProfile -Raw
        $pattern = '(?ms)^' + [regex]::Escape($startMarker) + '.*?^' + [regex]::Escape($endMarker) + '\s*(?:\r?\n)?'
        $updated = [regex]::Replace($content, $pattern, '')
        if ($updated -ne $content -and $PSCmdlet.ShouldProcess($resolvedProfile, 'Remove TheRiddler managed block')) {
            Set-Content -LiteralPath $resolvedProfile -Value $updated -Encoding UTF8 -NoNewline
        }
    }
}

if (Test-Path -LiteralPath $destination) {
    $root = [IO.Path]::GetPathRoot($destination)
    if ($destination -eq $root -or $destination.Length -lt ($root.Length + 4)) {
        throw "Refusing to remove unsafe install root '$destination'."
    }

    if (-not (Test-Path -LiteralPath $installMarker -PathType Leaf)) {
        throw "Refusing to remove '$destination' because it has no TheRiddler install marker."
    }
    $marker = Get-Content -LiteralPath $installMarker -Raw | ConvertFrom-Json
    if ($marker.product -ne 'TheRiddler') {
        throw "Refusing to remove '$destination' because its install marker is invalid."
    }

    if ($PSCmdlet.ShouldProcess($destination, 'Remove TheRiddler installation directory recursively')) {
        Remove-Item -LiteralPath $destination -Recurse -Force
    }
}

Write-Output "TheRiddler removed from '$destination'."

