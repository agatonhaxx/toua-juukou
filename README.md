![Toha Heavy Industries](./toua-juukou.webp)

# toua-juukou

My Nix configuration for all my machines.

- `hosts/` says what is special about each machine.
- `modules/` contains profiles, hardware, services, and shared system options.
- `user/` contains Home Manager applications and settings.
- `secrets/` contains only SOPS-encrypted secrets.

## How configuration works

Hosts select a machine profile:

```nix
toua.profiles.desktop.enable = true;
```

Profiles provide grouped defaults and platform policy:

```nix
toua.programs.defaults.enable = true;
toua.programs.gui.enable = true;
toua.services.defaults.enable = true;
```

Reusable defaults feed profiles; profiles can adapt those defaults and settings
to their platform. User configuration owns personal application preferences.
The host is the final authority on whether a program, service, or setting applies
to that machine, and can override profile values.

Individual programs and services remain opt-in unless a profile provides a
default. Profiles use `lib.mkDefault`, so host values take precedence. The
`programs.gui` group controls GUI defaults. The `headless` profile enables the
full set of infrastructure services (`acme`, `atuin`, `borgbackup`, `kanidm`,
`nginx`, `vaultwarden`) on top of the Tailscale service default; the workstation
profiles leave those off and hosts enable the ones they need individually.

## Hosts

| Host | Profile | Purpose |
| --- | --- | --- |
| `bender` | `desktop` | NixOS laptop |
| `baymax` | `desktop` | NixOS desktop workstation and backup destination |
| `mac` | `mac` | nix-darwin laptop |
| `ponkotsu` | `wsl` | WSL development machine |
| `wall-e` | `headless` | Public services and client backup destination |

Baymax is installed locally from a NixOS USB installer rather than by
`nixos-anywhere`; see `hosts/baymax/INSTALL.md`.

## Commands

```sh
just build                         # build this machine
just switch                        # build and activate this machine
just diff                          # build and explain the diff from the running system
just deploy wall-e root@wall-e     # activate a remote NixOS host
just check                         # run repository checks
just fmt                           # format files
just update nixpkgs                # update one flake input
just clean                         # delete old generations and optimise Nix
```

`just provision-wall-e root@HOST` installs Wall-E from scratch and wipes its
target disk. Do not run it for an ordinary update.

## Adding or changing a program

1. Add the application module under `modules/programs/cli/` or
   `modules/programs/gui/`. Both directories are imported wholesale, so the
   file is picked up without a list to edit.
2. Declare its `toua.programs.<name>.enable` option in the owning module.
3. Gate its configuration on the corresponding enable option. Keep MIME defaults
   beside the program configuration and gate them on the active Home Manager
   program's enable option.
4. Add its name to a group list in `modules/shared/options.nix`, such as
   `cliProgramNames` or `mediaProgramNames`, if it belongs in a reusable
   baseline that a profile can turn on.
5. Add or override it in a machine profile, then override it for a host when
   platform or machine constraints require it.

## Adding or changing a service

1. Add one service definition under `modules/services/`.
2. Declare its `toua.services.<name>` options in that file.
3. Gate its implementation on `toua.services.<name>.enable`.
4. On NixOS nothing else is needed: `modules/services/nixos.nix` imports every
   sibling file. Darwin services are listed by hand in
   `modules/services/default.nix`.
5. Use `services.defaults` only for services suitable as a broad baseline. The
   `headless` profile turns the infrastructure services on by default;
   workstation profiles leave them off and hosts enable the ones they need.

Atuin, Kanidm, and Vaultwarden require `toua.services.acme.enable` and
`toua.services.nginx.enable`. Vaultwarden also requires
`toua.services.kanidm.enable` for SSO. These dependencies must be enabled
explicitly or through the `headless` profile; missing dependencies fail assertions.
Set `toua.domain` for the service stack and `toua.email` for the ACME contact.
Kanidm user email addresses are configured separately under
`services.kanidm.provision.persons`.

## Adding a host

1. Add `hosts/<name>/default.nix`.
2. Register it in `hosts/default.nix`.
3. Set `toua.profiles`, `toua.primaryUser`, `toua.users`, and the host's
   hardware/filesystem options.
4. Generate its SSH host key and print the age recipient:

   ```sh
   just age-recipient /etc/ssh/ssh_host_ed25519_key.pub
   ```

5. Add that recipient to `.sops.yaml`, then update applicable secrets:

   ```sh
   just secrets-update
   ```

If the host has no SSH daemon, set `services.openssh.generateHostKeys = true`.
If activation needs a secret before the key can be generated, create the key
once with:

```sh
sudo ssh-keygen -t ed25519 -N '' -f /etc/ssh/ssh_host_ed25519_key
```

## Secrets

```text
secrets/
├── eek.yaml                         personal secrets
└── services/<service>.yaml          shared service secrets
```

```sh
just secret secrets/services/kanidm.yaml  # edit one secret
just secrets-update                       # apply .sops.yaml recipients
```

Never commit plaintext secrets. Keep an offline copy of the private age key
matching the `eek` recipient in `.sops.yaml`.

## Add a Kanidm/SSO user

1. Add the person under `services.kanidm.provision.persons` in
   `modules/services/kanidm.nix`. Include `vaultwarden.access` in `groups` if
they should use Vaultwarden.
2. Deploy Wall-E:

   ```sh
   just deploy wall-e root@wall-e
   ```

3. On Wall-E, log in as the Kanidm administrator and create a one-day setup
   link:

   ```sh
   kanidm login --name idm_admin
   kanidm person credential create-reset-token USERNAME --ttl 86400 --name idm_admin
   ```

Send the resulting link to the user. `86400` must follow `--ttl`.

## Add a Vaultwarden user

For an SSO user, add them to the Kanidm `vaultwarden.access` group as described
above. They then open `https://vault.huxe.eu`, choose SSO, and create their
separate Vaultwarden master password. Kanidm authenticates them; the master
password encrypts their vault.

For a password-only user, invite their email from
`https://vault.huxe.eu/admin`. The admin page expects the original plaintext
admin password, not the stored `$argon2...` hash.

## Add an Atuin user

Atuin has no administrator command for creating one user while registration is
closed. Temporarily change `openRegistration` to `true` in
`modules/services/atuin.nix`, deploy Wall-E, and let the user run:

```sh
atuin register -u USERNAME -e EMAIL
atuin key   # save this somewhere safe
```

Set `openRegistration` back to `false` and deploy Wall-E again immediately.

## Backups

Borg jobs are not wired up yet — see [Known gaps](#known-gaps). This is the
intended layout:

```text
bender/mac/ponkotsu -> Wall-E -> locked repository mirrors on Baymax
Wall-E services ----------------> separate repository on Baymax
```

Keep these offline:

- the private `eek` age identity;
- every Borg repository passphrase;
- `borg key export` from every initialized repository.

The Borg SSH public keys authorize SSH only; they cannot decrypt a backup.

Useful checks on a host:

```sh
systemctl list-timers | grep borg
systemctl status borgbackup-job-NAME
journalctl -u borgbackup-job-NAME
```

## Quick administration

```sh
systemctl status SERVICE       # service status
journalctl -u SERVICE -e       # recent service logs
sudo nixos-rebuild switch --rollback  # roll back NixOS
sudo darwin-rebuild switch --rollback # roll back macOS
```

Service URLs:

- Kanidm: `https://sso.huxe.eu`
- Vaultwarden: `https://vault.huxe.eu`
- Atuin: `https://atuin.huxe.eu`

## Known gaps

- **Borg backups are not wired up.** `modules/services/borgbackup.nix` implements
  jobs, mirrors and receiver repositories, but no host defines any, so the module
  is inert. Wiring it up also needs `keys/borg/<name>.pub` to exist and the
  `secrets/services/` rule in `.sops.yaml` to match the nested
  `secrets/services/borg/<host>/…` paths the module expects.
- **Bitwarden SSH agent.** `user/eek/system/env.nix` still carries a `REPLACE-ME`
  socket path for the Bitwarden desktop agent on macOS.
- **Services are not grouped like programs.** Only `services.defaults` exists,
  and it currently drives just the Tailscale default; the infrastructure services
  are enabled per profile or host instead.

See [TODO.md](TODO.md) for the scheduled work.
