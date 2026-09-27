# TheRiddler

TheRiddler is an opt-in PowerShell command shell for authorized red-team exercises. Every non-empty command entered inside the shell is held until the user answers one randomly selected riddle from a static inventory. A correct answer runs the command; a wrong answer drops it and prints a laugh.

It is intentionally an **annoyance control, not a security boundary**. A user who can start another shell, use `-NoProfile`, interrupt the process, or modify the installed files can bypass it. Use it only on systems and accounts that are explicitly in scope.

## Quick start

PowerShell 5.1 or PowerShell 7+ is supported.

```powershell
Import-Module .\src\TheRiddler\TheRiddler.psd1 -Force
Enter-TheRiddlerShell
```

Inside the shell:

```text
riddler PS C:\work> Get-Date

[TheRiddler] What has keys but cannot open locks?
Answer: piano
Correct. The command may pass.
Saturday, September 26, 2026 8:00:00 PM
```

An incorrect answer discards the command:

```text
Answer: banana
MUAHAHA! Wrong answer. Your command has vanished into the void.
```

Use `exit` as the command to leave the shell; it is gated by a riddle too. The shell accepts one logical line at a time. Pipelines, redirection, quoted arguments, aliases, functions, and native executables work normally, but PSReadLine history/completion and multiline editing are not available in this deliberately small REPL.

## Install for a user profile

The installer copies the module and riddle inventory to a stable directory, then optionally adds a clearly marked startup block to one PowerShell profile.

```powershell
.\scripts\Install-TheRiddler.ps1 `
  -InstallRoot 'C:\ProgramData\TheRiddler' `
  -ProfilePath 'C:\Users\exercise-user\Documents\PowerShell\Microsoft.PowerShell_profile.ps1' `
  -EnableProfile
```

The profile block imports TheRiddler and enters its shell only for an interactive console. When the gated shell exits, the PowerShell process exits as well, preventing a fall-through into an ordinary prompt.

Preview changes with `-WhatIf`. Remove the startup block and installed files with:

```powershell
.\scripts\Uninstall-TheRiddler.ps1 `
  -InstallRoot 'C:\ProgramData\TheRiddler' `
  -ProfilePath 'C:\Users\exercise-user\Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
```

Run uninstall from a `-NoProfile` PowerShell session if profile activation is enabled:

```powershell
pwsh -NoProfile
```

## One-command wrapper

For demos, scripts, and tests, gate a single script block:

```powershell
Invoke-TheRiddlerCommand -Command { Get-Service } -RiddleId keys -Answer piano
```

Omit `-Answer` to prompt. `-RiddleId` exists for deterministic exercises; omit it to select randomly.

## Static inventory

Riddles live in [`inventory/riddles.json`](inventory/riddles.json). Each record has a stable `id`, a `question`, and one or more accepted `answers`. Matching is case-insensitive, trims surrounding whitespace, collapses repeated spaces, and ignores a final sentence punctuation mark. Inventory contents are validated when the module loads.

## Tests

```powershell
pwsh -NoProfile -File .\tests\Test-TheRiddler.ps1
```

## Using TheRiddler with Commando

Commando's agent is a non-interactive background process, so do not put a riddle prompt around the agent itself: it has nobody at the keyboard to answer and its tasks will time out. Instead, use Commando as the authorized deployment/control plane and TheRiddler as the interactive user-shell payload.

The clean Windows workflow is:

1. Stage this repository (or a reviewed release of it) on the authorized target by your approved file-distribution method.
2. In both Commando's event-policy host entry and that host's local agent config, explicitly set `allowUnrestrictedPowerShell: true`.
3. Queue a `powershell_script` task that invokes `scripts\Install-TheRiddler.ps1` with an exact install root and exact target-user profile path.
4. The next interactive PowerShell session for that profile enters TheRiddler. Commando continues polling and executing in the background because its process does not load the user's interactive profile.
5. Queue the uninstall script before the exercise ends, then verify the marked profile block and install directory are gone.

Example Commando script after the files have been staged as `C:\CompetitionTools\TheRiddler`:

```powershell
& 'C:\CompetitionTools\TheRiddler\scripts\Install-TheRiddler.ps1' `
  -InstallRoot 'C:\ProgramData\TheRiddler' `
  -ProfilePath 'C:\Users\exercise-user\Documents\PowerShell\Microsoft.PowerShell_profile.ps1' `
  -EnableProfile
```

Rollback task:

```powershell
& 'C:\CompetitionTools\TheRiddler\scripts\Uninstall-TheRiddler.ps1' `
  -InstallRoot 'C:\ProgramData\TheRiddler' `
  -ProfilePath 'C:\Users\exercise-user\Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
```

This integration is Windows-only with the current Commando implementation: its `powershell_script` tasks are rejected by Linux agents. Keep the target explicitly listed in the event policy, preserve Commando's transcripts, rehearse install/rollback on a clone, and do not enable unrestricted PowerShell globally just for this tool.

