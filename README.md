![Toha Heavy Industries](./toua-juukou.webp)

# toua-juukou

My Nix configuration for all my machines.

- `hosts/` says what is special about each machine.
- `modules/` contains profiles, hardware, services, and shared system options.
- `pkgs/` contains custom package builds and the shared Nixpkgs overlay.
- `user/` contains Home Manager applications and settings.
- `secrets/` contains only SOPS-encrypted secrets.

## How configuration works

Hosts select a machine profile:

```nix
toua.profiles.desktop.enable = true;
```

All `toua.programs.<name>.enable` and `toua.services.<name>.enable` options
default to false. `modules/groups.nix` holds reusable selections with the same
shape regardless of whether a tool uses Home Manager, a package, Homebrew, or a
service module:

```nix
dev.programs = {
  just.enable = true;
  jq.enable = true;
};
server.services = {
  nginx.enable = true;
  atuin.enable = true;
};
```

Profiles compose groups using the helpers in `modules/shared/lib.nix`:

```nix
config.toua = lib.mkIf cfg.enable (lib.mkMerge [
  (mkDefaults groups.cli)
  (mkDefaults groups.dev)
  (mkDefaults groups.network)
]);
```

`mkDefaults` applies `lib.mkDefault` to each setting. Hosts override individual
settings with ordinary assignments, for example `toua.programs.just.enable = false;`.
Group selection is explicit; there are no group enable switches. The desktop and
Mac profiles select CLI, GUI, media, and network groups; WSL selects CLI and
network; headless additionally selects the server group.

Home Manager declares corresponding user-owned `toua.programs` options in
`user/options.nix` and inherits the effective host selections as defaults. User
modules can override these and configure native application options:

```nix
toua.programs.jq.enable = false;
programs.atuin.settings.auto_sync = true;
```

Machine services and Homebrew installations resolve at profile → host level.
Home Manager programs and packages (including Flow) resolve at
profile → host → user level. On Darwin, enabling user configuration for Firefox,
Chromium, VS Code, or KiwiDesk requires the application to be installed at host
level; disabling its user configuration does not uninstall the cask.

`toua.graphical.enable` controls graphical user settings independently of program
selection. `toua.fonts.enable` controls fonts. Both are false unless explicitly
selected by a profile, host, or user.

## Hosts

| Host | Profile | Purpose |
| --- | --- | --- |
| `bender` | `desktop` | NixOS laptop |
| `baymax` | `desktop` | NixOS desktop workstation, media server, and backup destination |
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

1. Add its name to a program group in `modules/groups.nix`, or declare an
   ungrouped option in `modules/shared/options.nix`. Darwin-only cask options are
   declared in `modules/darwin/options.nix`.
2. For simple Home Manager toggles, add its name to
   `modules/programs/cli/defaults.nix` or `gui/defaults.nix`. Package-only tools
   use the explicit package mappings; simple casks use `homebrew/defaults.nix`.
3. Keep dedicated modules for additional behavior, platform handling, and MIME
   associations. Home Manager implementations read `config.toua.programs`;
   machine implementations read their system `config.toua.programs`.
4. Select the group in a profile or host, then override individual toggles and
   native options at host or user level as appropriate.

Custom builds live under `pkgs/<name>/package.nix` and are exposed through
`pkgs/overlay.nix`. Flow is available as `pkgs.flow` and `nix build .#flow` on
Intel and ARM Linux/macOS. `toua.programs.flow.enable` installs it for the user;
profiles select it through the media group. Linux uses the upstream Debian
package with Nix-managed GTK, WebKit, GStreamer codecs, and the Node fallback.

`pkgs.mouse-wheel-debounce` drops mouse wheel encoder chatter. It is not a
program but a filter on one device: baymax runs it between that wheel and
libinput through interception-tools, so the events it discards are events no
compositor sees. It is wired up in `hosts/baymax/default.nix` rather than in a
module, because it answers one failing wheel and not a fleet-wide policy.

## Adding or changing a service

1. Add one service definition under `modules/services/` (loaded on every class)
   or `modules/nixos/services/` (NixOS only).
2. Declare its `toua.services.<name>` options in that file.
3. Gate its implementation on `toua.services.<name>.enable`.
4. Nothing else is needed: each directory's `default.nix` imports every sibling
   through `importDir`. NixOS imports both directories; Darwin imports only
   `modules/services/`, which is why a service touching `security.acme`,
   `services.nginx` or `toua.domain` belongs in `modules/nixos/services/`.
5. Add suitable services to a group in `modules/groups.nix` and select it in a
   profile or host. The `network` group selects Tailscale; `server` selects the
   infrastructure stack; `media.services` selects the media stack, which needs a
   data volume and a group its services share, so no profile selects it. Service
   enable options always default to false.

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
   `modules/nixos/services/kanidm.nix`. Include `vaultwarden.access` in `groups`
   if they should use Vaultwarden.
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
`modules/nixos/services/atuin.nix`, deploy Wall-E, and let the user run:

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
- MediaManager: `http://127.0.0.1:8000` on Baymax, which is not proxied; reach it
  over the LAN or an SSH tunnel. Its `toua.services.mediamanager` secret needs
  `just secret secrets/services/mediamanager.yaml` to exist before it is enabled.

The media services run on Baymax and are reached over the LAN:

- Jellyfin: `http://baymax:8096`
- qBittorrent: `http://baymax:8080` — its save paths and password are the WebUI's
- SABnzbd: `http://baymax:8081`
- slskd: `http://baymax:5030`, which needs
  `just secret secrets/services/slskd.yaml` to exist before it is enabled
- Navidrome: `http://baymax:4533`
- immich: `http://baymax:2283`

They keep their state under `/data/baymax/qt` and share the libraries and
download trees through the `media` group, which your user is in as well; the
trees were regrouped once and the command for it is in
`hosts/baymax/default.nix`.

## Recovering the immich database

The immich library on Baymax predates this configuration — a Docker install
served it — and the dumps of that install's PostgreSQL 14 database are in
`/data/baymax/qt/immich/backups`. They were taken with pgvecto.rs and are loaded
into the cluster here once, by `hosts/baymax/immich-restore.sh`, which rewrites
them for it:

```sh
just switch                            # creates the cluster, the role and the database
sudo ./hosts/baymax/immich-restore.sh  # shelter, preprocess, load
sudo systemctl start immich-server     # immich's migrations 2.7.5 -> 3.2.1 run here
sudo ./hosts/baymax/immich-restore.sh verify
```

The dumps are copied out of the directory immich's own backup job writes into
and prunes, and nothing is deleted, so the load can be repeated from the same
dump. immich rebuilds `face_index` and `clip_index` itself on its first start.

No immich version is pinned for it. The dump's 68 rows in `kysely_migrations`
are the first 68 entries of the `ORDER` file in `server/src/schema/migrations/`
of the 3.2.1 source, so the 28 migrations left are a clean continuation. That
was checked against

```sh
nix build --out-link /tmp/immich-src .#nixosConfigurations.baymax.config.services.immich.package.src
ls /tmp/immich-src/server/src/schema/migrations/
```

and `SELECT name FROM kysely_migrations;`; redo it if the dump or the package
moves and a recorded name is no longer upstream — stepping through an
intermediate release is the alternative. Delete the script and this section once
the library has been checked.

## Known gaps

- **Borg backups are not wired up.** `modules/nixos/services/borgbackup.nix`
  implements jobs, mirrors and receiver repositories, but no host defines any,
  so the module is inert. Wiring it up also needs `keys/borg/<name>.pub` to
  exist and the `secrets/services/` rule in `.sops.yaml` to match the nested
  `secrets/services/borg/<host>/…` paths the module expects.
- **Bitwarden SSH agent.** `user/eek/system/env.nix` still carries a `REPLACE-ME`
  socket path for the Bitwarden desktop agent on macOS.

See [TODO.md](TODO.md) for the scheduled work.
