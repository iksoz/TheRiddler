# TheRiddler

TheRiddler is a annoying PowerShell shell that when a user types a command, they have to answer a random riddle, and the command runs or else the command will fail. 

Anyone who can open another shell, use `-NoProfile` to stop the process or edit the installed files can get around it.

## Install it for a user

The installer copies the module and riddle list to a stable location. With `-EnableProfile`, it also adds a marked block to the profile you specify.

```powershell
.\scripts\Install-TheRiddler.ps1 `
  -InstallRoot 'C:\ProgramData\TheRiddler' `
  -ProfilePath 'C:\Users\exercise-user\Documents\PowerShell\Microsoft.PowerShell_profile.ps1' `
  -EnableProfile
```

The profile block only starts TheRiddler in an interactive console. Leaving TheRiddler also closes that PowerShell process, so it cannot fall through to an ordinary prompt.

Use `-WhatIf` to preview the installation. To remove it:

```powershell
.\scripts\Uninstall-TheRiddler.ps1 `
  -InstallRoot 'C:\ProgramData\TheRiddler' `
  -ProfilePath 'C:\Users\exercise-user\Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
```

If profile activation is on, run the uninstaller from a no-profile session:

```powershell
pwsh -NoProfile
```

## Gate one command

You can use the module without entering its shell:

```powershell
Invoke-TheRiddlerCommand -Command { Get-Service } -RiddleId keys -Answer piano
```

Leave out `-Answer` to get an interactive prompt. `-RiddleId` is useful for demos and tests; without it, the module picks a riddle at random.

## Riddle list

The riddles are in [`inventory/riddles.json`](inventory/riddles.json). Each entry needs a unique `id`, a `question`, and at least one accepted answer. Answer matching ignores case, extra surrounding or repeated spaces, and punctuation at the end. The module checks the inventory when it loads.

## Tests

```powershell
pwsh -NoProfile -File .\tests\Test-TheRiddler.ps1
pwsh -NoProfile -File .\tests\Test-AnsibleHelpers.ps1
```

## Ansible deployment

[`ansible/deploy.yml`](ansible/deploy.yml) contains the deployment playbook for the CDT Alpha Windows Server 2019 hosts. It is reversible, uses an explicit Windows-only inventory, requires exact profile paths, and rejects the competition's off-limits Grey Team accounts.

See [`ansible/README.md`](ansible/README.md) for controller setup, preflight checks, deployment, and rollback.

## Commando

 The agent runs in the background with nobody there to answer a prompt, so its jobs will time out. Use Commando to deploy TheRiddler to interactive user shells instead.

A typical setup looks like this:

1. Put this repository, or a reviewed release, on the authorized target.
2. Set `allowUnrestrictedPowerShell: true` for that host in both Commando's event policy and the local agent config.
3. Queue a `powershell_script` job that runs `scripts\Install-TheRiddler.ps1` with the exact install root and user profile path.
4. The user's next interactive PowerShell session starts TheRiddler. The Commando agent keeps running because it does not load that interactive profile.
5. Before the exercise ends, run the uninstaller and check that both the profile block and install directory are gone.

For a copy staged at `C:\CompetitionTools\TheRiddler`, the install job is:

```powershell
& 'C:\CompetitionTools\TheRiddler\scripts\Install-TheRiddler.ps1' `
  -InstallRoot 'C:\ProgramData\TheRiddler' `
  -ProfilePath 'C:\Users\exercise-user\Documents\PowerShell\Microsoft.PowerShell_profile.ps1' `
  -EnableProfile
```
