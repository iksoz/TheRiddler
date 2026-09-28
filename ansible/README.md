# Competition Ansible deployment

This playbook deploys TheRiddler only to the five Windows Server 2019 hosts in the
CDT Alpha preliminary environment. It deliberately excludes the Linux subnet and
does not change scored services, firewalls, antivirus, users, passwords, or system-wide
PowerShell profiles.

The deployment runs one host at a time and stops on the first error. The profile
guard accepts only the packet-declared Blue Team account names and rejects paths
outside `C:\Users`, nonexistent user profile directories, and the two off-limits
Grey Team account names.

## Controller setup

Run Ansible from Linux or WSL. Install Ansible, its WinRM dependency, and the pinned
Windows collection:

```bash
python3 -m pip install ansible pywinrm
ansible-galaxy collection install -r ansible/collections/requirements.yml
```

The targets must already accept WinRM connections from the controller. The supplied
inventory uses NTLM over port 5985 so it works with either authorized local or domain
credentials. If the event exposes WinRM over HTTPS instead, change the inventory to
port 5986 and configure certificate validation appropriately. Do not weaken endpoint
security or alter firewall rules just to make this playbook connect.

## Credentials and target profiles

Do not put competition passwords in the repository. Supply the authorized WinRM user
with `--user` and its password with `--ask-pass`, or place both in an encrypted Ansible
Vault vars file.

The playbook also requires the exact profile path for every authorized Blue Team user
that should receive TheRiddler. Windows PowerShell 5.1 normally uses:

```text
C:\Users\AUTHORIZED_USER\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
```

PowerShell 7 normally uses `Documents\PowerShell` instead. Confirm the actual user
profile directories on the target; do not guess them and do not use an all-users
profile.

Copy the ignored local variables example and replace the placeholder with exact paths:

```bash
cp ansible/vars/riddler-targets.example.yml ansible/vars/riddler-targets.yml
```

The resulting `ansible/vars/riddler-targets.yml` should look like:

```yaml
riddler_profile_paths:
  - 'C:\Users\AUTHORIZED_BLUE_USER\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'
```

## Preflight and deployment

First confirm that the credentials and event-side WinRM configuration work:

```bash
ansible competition_windows \
  -i ansible/inventory/competition.yml \
  -m ansible.windows.win_ping \
  --user AUTHORIZED_USER \
  --ask-pass
```

On the Linux or WSL controller, validate the playbook itself before contacting hosts:

```bash
ansible-playbook ansible/deploy.yml \
  -i ansible/inventory/competition.yml \
  -e @ansible/vars/riddler-targets.yml \
  --syntax-check
```

Preview the intended changes. PowerShell scripts in this deployment support Ansible
check mode, although file modules may still report predicted changes:

```bash
ansible-playbook ansible/deploy.yml \
  -i ansible/inventory/competition.yml \
  -e @ansible/vars/riddler-targets.yml \
  --user AUTHORIZED_USER \
  --ask-pass \
  --check --diff
```

Deploy during the authorized competition window:

```bash
ansible-playbook ansible/deploy.yml \
  -i ansible/inventory/competition.yml \
  -e @ansible/vars/riddler-targets.yml \
  --user AUTHORIZED_USER \
  --ask-pass
```

Use `--limit coruscant` (or another inventory hostname) to rehearse on a single
authorized host before deploying to the whole Windows group.

## Rollback

Use the same target profile list so every managed block is removed before the runtime
directory. The removal refuses to recurse unless the destination has a valid
TheRiddler ownership marker.

```bash
ansible-playbook ansible/deploy.yml \
  -i ansible/inventory/competition.yml \
  -e @ansible/vars/riddler-targets.yml \
  -e riddler_state=absent \
  --user AUTHORIZED_USER \
  --ask-pass
```

If central orchestration is unavailable, an administrator can use the installed
`scripts\Uninstall-TheRiddler.ps1` from a `powershell.exe -NoProfile` session, passing
the exact install root and profile path.
