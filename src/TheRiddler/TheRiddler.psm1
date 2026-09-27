Set-StrictMode -Version 2.0

$script:InventoryPath = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) 'inventory\riddles.json'
$script:LaughMessages = @(
    'MUAHAHA! Wrong answer. Your command has vanished into the void.',
    'HA! The riddle wins. That command goes nowhere.',
    'HEH HEH HEH... incorrect. Command denied by the keeper of keys.',
    'BWAHAHA! Nice try. The command has been cast into oblivion.'
)
$script:Riddles = @()

function ConvertTo-TheRiddlerNormalizedAnswer {
    param([AllowNull()][string]$Answer)

    if ($null -eq $Answer) {
        return ''
    }

    $normalized = $Answer.Trim().ToLowerInvariant()
    $normalized = $normalized -replace '\s+', ' '
    $normalized = $normalized -replace '[\.!?,;:]+$', ''
    return $normalized.Trim()
}

function Import-TheRiddlerInventory {
    if (-not (Test-Path -LiteralPath $script:InventoryPath -PathType Leaf)) {
        throw "TheRiddler inventory was not found at '$script:InventoryPath'."
    }

    $items = @(Get-Content -LiteralPath $script:InventoryPath -Raw -Encoding UTF8 | ConvertFrom-Json)
    if ($items.Count -eq 0) {
        throw 'TheRiddler inventory must contain at least one riddle.'
    }

    $seen = @{}
    foreach ($item in $items) {
        if ([string]::IsNullOrWhiteSpace([string]$item.id) -or
            [string]::IsNullOrWhiteSpace([string]$item.question) -or
            $null -eq $item.answers -or @($item.answers).Count -eq 0) {
            throw 'Every riddle requires a non-empty id, question, and answers array.'
        }

        if ($seen.ContainsKey([string]$item.id)) {
            throw "Duplicate riddle id '$($item.id)'."
        }
        $seen[[string]$item.id] = $true

        foreach ($answer in @($item.answers)) {
            if ([string]::IsNullOrWhiteSpace([string]$answer)) {
                throw "Riddle '$($item.id)' contains an empty accepted answer."
            }
        }
    }

    $script:Riddles = $items
}

function Get-TheRiddlerRiddle {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Id
    )

    if ($PSBoundParameters.ContainsKey('Id')) {
        $match = @($script:Riddles | Where-Object { $_.id -eq $Id })
        if ($match.Count -ne 1) {
            throw "No riddle exists with id '$Id'."
        }
        return $match[0]
    }

    return $script:Riddles | Get-Random
}

function Test-TheRiddlerAnswer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [object]$Riddle,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Answer
    )

    process {
        $candidate = ConvertTo-TheRiddlerNormalizedAnswer -Answer $Answer
        foreach ($accepted in @($Riddle.answers)) {
            if ($candidate -ceq (ConvertTo-TheRiddlerNormalizedAnswer -Answer ([string]$accepted))) {
                return $true
            }
        }
        return $false
    }
}

function Read-TheRiddlerChallenge {
    param(
        [Parameter(Mandatory)]
        [object]$Riddle,

        [AllowNull()]
        [string]$Answer,

        [Parameter(Mandatory)]
        [bool]$AnswerWasProvided
    )

    Write-Host ''
    Write-Host "[TheRiddler] $($Riddle.question)" -ForegroundColor Yellow
    if (-not $AnswerWasProvided) {
        $Answer = Read-Host 'Answer'
    }

    if (Test-TheRiddlerAnswer -Riddle $Riddle -Answer $Answer) {
        Write-Host 'Correct. The command may pass.' -ForegroundColor Green
        return $true
    }

    Write-Host ($script:LaughMessages | Get-Random) -ForegroundColor Red
    return $false
}

function Invoke-TheRiddlerCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNull()]
        [scriptblock]$Command,

        [Parameter()]
        [AllowEmptyString()]
        [string]$Answer,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$RiddleId
    )

    $riddleParameters = @{}
    if ($PSBoundParameters.ContainsKey('RiddleId')) {
        $riddleParameters.Id = $RiddleId
    }
    $riddle = Get-TheRiddlerRiddle @riddleParameters
    $provided = $PSBoundParameters.ContainsKey('Answer')
    if (-not (Read-TheRiddlerChallenge -Riddle $riddle -Answer $Answer -AnswerWasProvided $provided)) {
        $global:LASTEXITCODE = 1
        return
    }

    & $Command
}

function Enter-TheRiddlerShell {
    [CmdletBinding()]
    param()

    Write-Host 'TheRiddler shell is active. Every command requires one correct answer.' -ForegroundColor Cyan
    Write-Host "Enter 'exit' to leave (yes, it is gated too). Press Ctrl+C to cancel the current prompt." -ForegroundColor DarkGray

    while ($true) {
        $location = (Get-Location).Path
        try {
            $line = Read-Host "riddler PS $location>"
        }
        catch [System.Management.Automation.PipelineStoppedException] {
            Write-Host ''
            continue
        }

        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $riddle = Get-TheRiddlerRiddle
        try {
            $passed = Read-TheRiddlerChallenge -Riddle $riddle -Answer $null -AnswerWasProvided $false
        }
        catch [System.Management.Automation.PipelineStoppedException] {
            Write-Host ''
            $global:LASTEXITCODE = 130
            continue
        }

        if (-not $passed) {
            $global:LASTEXITCODE = 1
            continue
        }

        if ($line.Trim() -ieq 'exit') {
            return
        }

        try {
            Invoke-Expression $line
        }
        catch {
            Write-Error -ErrorRecord $_
        }
    }
}

Import-TheRiddlerInventory
Export-ModuleMember -Function Enter-TheRiddlerShell, Get-TheRiddlerRiddle, Invoke-TheRiddlerCommand, Test-TheRiddlerAnswer

