Set-StrictMode -Version 2.0

# Module state is deliberately private. Importing the module validates the inventory once,
# then all exported commands operate on that validated in-memory collection.
$script:InventoryPath = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) 'inventory\riddles.json'
$script:LaughMessages = @(
    'MUAHAHA! Wrong answer. Your command has vanished into the void.',
    'HA! The riddle wins. That command goes nowhere.',
    'HEH HEH HEH... incorrect. Command denied by the keeper of keys.',
    'BWAHAHA! Nice try. The command has been cast into oblivion.'
)
$script:Riddles = @()

function ConvertTo-TheRiddlerNormalizedAnswer {
    # Keep answer matching friendly but predictable: ignore case, repeated whitespace,
    # and sentence-ending punctuation without changing punctuation inside an answer.
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
    # Fail during module import rather than during a competition prompt. This keeps a
    # malformed or ambiguous inventory from partially activating TheRiddler.
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
    <#
    .SYNOPSIS
    Returns a specific riddle or selects one randomly from the validated inventory.
    .PARAMETER Id
    Optional stable inventory id. An unknown or duplicate id is treated as an error.
    #>
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
    <#
    .SYNOPSIS
    Tests a supplied answer against every accepted answer for a riddle.
    .DESCRIPTION
    Both values are normalized by ConvertTo-TheRiddlerNormalizedAnswer before an
    ordinal comparison. The function returns a Boolean and does not write prompts.
    #>
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
    # This private UI helper supports both interactive prompting and deterministic
    # callers/tests that supply an answer up front.
    param(
        [Parameter(Mandatory)]
        [object]$Riddle,

        [AllowNull()]
        [string]$Answer,

        [Parameter(Mandatory)]
        [bool]$AnswerWasProvided
    )

    Write-Host ''
    Write-Host $Riddle.question -ForegroundColor Yellow
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
    <#
    .SYNOPSIS
    Runs a script block only after a correct riddle answer.
    .DESCRIPTION
    A rejected answer never invokes the script block and sets LASTEXITCODE to 1 so
    native-style callers can detect the denial.
    .PARAMETER Command
    Script block to invoke after the challenge succeeds.
    .PARAMETER Answer
    Optional pre-supplied answer. Omit it to prompt interactively.
    .PARAMETER RiddleId
    Optional fixed riddle id, primarily useful for repeatable tests or demonstrations.
    #>
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
    <#
    .SYNOPSIS
    Starts an interactive PowerShell loop that gates each command with a riddle.
    .DESCRIPTION
    The shell accepts one logical input line at a time. A wrong answer discards the
    pending command. The exit command is gated and returns from this loop only after
    a correct answer.
    #>
    [CmdletBinding()]
    param()

    while ($true) {
        $location = (Get-Location).Path
        try {
            $line = Read-Host "PS $location>"
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

        # Handle exit after the challenge so leaving the shell follows the same rule
        # as every other command.
        if ($line.Trim() -ieq 'exit') {
            return
        }

        try {
            # The user's line is intentionally evaluated as PowerShell. This module is
            # an opt-in competition prompt, not a security boundary or command sandbox.
            Invoke-Expression $line
        }
        catch {
            Write-Error -ErrorRecord $_
        }
    }
}

# Eager validation prevents a broken inventory from exposing partially working commands.
Import-TheRiddlerInventory
Export-ModuleMember -Function Enter-TheRiddlerShell, Get-TheRiddlerRiddle, Invoke-TheRiddlerCommand, Test-TheRiddlerAnswer

