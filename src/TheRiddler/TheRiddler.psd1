@{
    RootModule = 'TheRiddler.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'b3aed44c-45dc-4d57-a29c-451559d94b20'
    Author = 'TheRiddler contributors'
    CompanyName = 'Community'
    Copyright = '(c) 2026 TheRiddler contributors'
    Description = 'An opt-in riddle gate for interactive PowerShell commands during authorized exercises.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Enter-TheRiddlerShell',
        'Get-TheRiddlerRiddle',
        'Invoke-TheRiddlerCommand',
        'Test-TheRiddlerAnswer'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Riddle', 'PowerShell', 'RedTeam', 'Exercise')
            ProjectUri = 'https://example.invalid/TheRiddler'
        }
    }
}

