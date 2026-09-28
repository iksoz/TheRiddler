$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw "Assertion failed: $Message"
    }
}

$repositoryRoot = Split-Path $PSScriptRoot -Parent
$helperRoot = Join-Path $repositoryRoot 'ansible\files'
$profileHelper = Join-Path $helperRoot 'Set-TheRiddlerProfile.ps1'

foreach ($scriptPath in Get-ChildItem -LiteralPath $helperRoot -Filter '*.ps1') {
    $tokens = $null
    $parseErrors = $null
    [Management.Automation.Language.Parser]::ParseFile(
        $scriptPath.FullName,
        [ref]$tokens,
        [ref]$parseErrors
    ) | Out-Null
    Assert-True ($parseErrors.Count -eq 0) "$($scriptPath.Name) must parse without errors."
}

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('TheRiddler-Ansible-' + [guid]::NewGuid())
$testProfile = Join-Path $testRoot 'Microsoft.PowerShell_profile.ps1'
$manifest = 'C:\ProgramData\TheRiddler\src\TheRiddler\TheRiddler.psd1'

try {
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    [IO.File]::WriteAllText($testProfile, "Write-Host 'existing profile content'", [Text.UTF8Encoding]::new($true))

    $global:Ansible = [pscustomobject]@{ Changed = $false; Result = $null }
    & $profileHelper -ProfilePath $testProfile -ManifestPath $manifest -State Present
    $firstInstall = [IO.File]::ReadAllText($testProfile)
    Assert-True $global:Ansible.Changed 'The first profile installation must report a change.'
    Assert-True ($firstInstall -like "*Write-Host 'existing profile content'*") 'Existing profile content must be preserved.'
    Assert-True ($firstInstall -like '*$Host.Name*') 'The literal PowerShell host guard must be preserved.'
    Assert-True (([regex]::Matches($firstInstall, '# >>> TheRiddler managed block >>>')).Count -eq 1) 'Exactly one managed block must be present.'

    $global:Ansible.Changed = $false
    & $profileHelper -ProfilePath $testProfile -ManifestPath $manifest -State Present
    $secondInstall = [IO.File]::ReadAllText($testProfile)
    Assert-True (-not $global:Ansible.Changed) 'An identical second installation must be idempotent.'
    Assert-True ($secondInstall -ceq $firstInstall) 'An identical second installation must not rewrite the profile.'

    $global:Ansible.Changed = $false
    & $profileHelper -ProfilePath $testProfile -State Absent
    $removed = [IO.File]::ReadAllText($testProfile)
    Assert-True $global:Ansible.Changed 'Removing an installed block must report a change.'
    Assert-True ($removed -notlike '*TheRiddler managed block*') 'Rollback must remove the managed block.'
    Assert-True ($removed -like "*Write-Host 'existing profile content'*") 'Rollback must preserve unrelated profile content.'

    $global:Ansible.Changed = $false
    & $profileHelper -ProfilePath $testProfile -State Absent
    Assert-True (-not $global:Ansible.Changed) 'Repeated rollback must be idempotent.'

    [IO.File]::WriteAllText($testProfile, '# >>> TheRiddler managed block >>>', [Text.UTF8Encoding]::new($true))
    $rejectedMalformedBlock = $false
    try {
        & $profileHelper -ProfilePath $testProfile -ManifestPath $manifest -State Present
    } catch {
        $rejectedMalformedBlock = $_.Exception.Message -like '*malformed or duplicate*'
    }
    Assert-True $rejectedMalformedBlock 'A malformed managed block must be rejected instead of overwritten.'
} finally {
    Remove-Variable -Name Ansible -Scope Global -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}

Write-Host 'All Ansible helper tests passed.' -ForegroundColor Green
