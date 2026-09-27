[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path $PSScriptRoot -Parent
$manifest = Join-Path $repositoryRoot 'src\TheRiddler\TheRiddler.psd1'
Import-Module $manifest -Force

$failures = [Collections.Generic.List[string]]::new()
function Assert-True {
    # Accumulate failures so a single run reports every violated invariant.
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { $failures.Add($Message) }
}

# Validate inventory structure before testing individual command-gating behavior.
$riddles = @(& (Get-Module TheRiddler) { $script:Riddles })
Assert-True ($riddles.Count -ge 20) 'Expected at least 20 static riddles.'
Assert-True ((@($riddles.id | Sort-Object -Unique)).Count -eq $riddles.Count) 'Riddle ids must be unique.'

$keys = Get-TheRiddlerRiddle -Id keys
Assert-True (Test-TheRiddlerAnswer -Riddle $keys -Answer ' Piano! ') 'Answer normalization should accept case, whitespace, and final punctuation.'
Assert-True (-not (Test-TheRiddlerAnswer -Riddle $keys -Answer 'organ')) 'An incorrect answer must fail.'

# Prove that the gate controls execution, not merely its displayed messages.
$script:ran = $false
Invoke-TheRiddlerCommand -Command { $script:ran = $true } -RiddleId keys -Answer piano
Assert-True $script:ran 'A command with a correct answer should execute.'

$script:blocked = $false
Invoke-TheRiddlerCommand -Command { $script:blocked = $true } -RiddleId keys -Answer wrong
Assert-True (-not $script:blocked) 'A command with an incorrect answer must not execute.'
Assert-True ($global:LASTEXITCODE -eq 1) 'A blocked command should set LASTEXITCODE to 1.'

try {
    Get-TheRiddlerRiddle -Id missing-riddle | Out-Null
    $failures.Add('An unknown riddle id should throw.')
} catch {
    Assert-True ($_.Exception.Message -like '*No riddle exists*') 'Unknown-id error should be clear.'
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "All TheRiddler tests passed ($($riddles.Count) riddles validated)." -ForegroundColor Green

