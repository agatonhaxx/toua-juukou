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
   use the explicit package mappings; simple casks use
   `modules/darwin/brew/defaults.nix`.
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
2. Declare its `toua.services.<name>` options in that file, normally through
   `mkServiceOption`; Radarr and Sonarr share `mkArr` in
   `modules/shared/lib.nix` for the same reason.
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

Two enabled services on one host cannot hold the same port, so
`modules/shared/ports.nix` asserts that. A service declared with a default port
of 0 binds none of its own and is outside the check, which is how the services
that only ever sit behind nginx are declared.

`mkServiceOption` also declares `proxy`, which a host sets to front a service
that runs on another machine through its own nginx. Wall-E serves the Baymax
media services that way, so their `enable` stays false there and only their
`domain` and `proxy` are set; `modules/nixos/services/proxy.nix` renders the
vhosts and certificates from each service's own port.

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
3. Set `toua.profiles` and the host's hardware/filesystem options. Nothing has to
   be said about users: the primary user defaults to `eek`, is always managed,
   and its Home Manager tree defaults to `user/eek`. Name `toua.primaryUser`, or
   add a `toua.users` entry with its own `homeModule`, only when a host differs.
4. Generate its SSH host key and print the age recipient:

   ```sh
   just age-recipient /etc/ssh/ssh_host_ed25519_key.pub
   ```

5. Add that recipient to the `keys:` block in `.sops.yaml` and to the `&huxe`
   list under it, then update applicable secrets:

   ```sh
   just secrets-update
   ```

If the host has no SSH daemon, set `services.openssh.generateHostKeys = true`.
If activation needs a secret before the key can be generated, create the key
once with:

```sh
sudo ssh-keygen -t ed25519 -N '' -f /etc/ssh/ssh_host_ed25519_key
```

A new NixOS host also needs its `preauthkey-<host>` entry in
`secrets/services/tailscale.yaml` before it can be built — see
[Tailnet](#tailnet).

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

## Tailnet

Wall-E runs [Headscale](https://headscale.net) as the tailnet's control server
at `https://headscale.huxe.eu`, so the fleet does not depend on Tailscale's own
coordination service, and serves its own DERP relay on UDP 3478 next to
Tailscale's public ones. Inside the tailnet, MagicDNS resolves names under
`tailnet.huxe.eu`, which is what lets Wall-E reach the Baymax services as
`baymax`.

`headscale.huxe.eu` needs a Cloudflare A/AAAA record pointing at Wall-E, and UDP
3478 has to reach the box for the relay to be useful.

Each NixOS host enrols itself with a reusable preauth key named after that host,
so one key can be revoked without touching the others. Create the tailnet's user
once and mint a key per host with the `headscale` command on Wall-E — its own
`headscale --help` is the reference for the user and key subcommands — then store
the key in `secrets/services/tailscale.yaml` as `preauthkey-<host>`:

```sh
headscale --help
just secret secrets/services/tailscale.yaml
```

That file has to exist before a host that reads it can be built: sops-nix checks
for its path during evaluation. A node keeps the control server it registered
with, so a host still on Tailscale's own server logs out once before the switch
that moves it:

```sh
sudo tailscale logout
sudo nixos-rebuild switch
```

macOS is the exception, since nix-darwin's Tailscale module takes no login
server and no auth key. Building that host prints the one manual command to run:

```sh
sudo tailscale logout
sudo tailscale up --login-server=https://headscale.huxe.eu --auth-key=<preauthkey-mac>
```

Keep `/var/lib/headscale` backed up: `db.sqlite` holds the nodes, and
`noise_private.key` and `derp_server_private.key` cannot be regenerated without
re-enrolling every node.

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
- Tailnet control server: `https://headscale.huxe.eu` (see [Tailnet](#tailnet))

The media services run on Baymax and are reached over the LAN:

- Jellyfin: `http://baymax:8096`
- qBittorrent: `http://baymax:8080`
- SABnzbd: `http://baymax:8081`
- Prowlarr: `http://baymax:9696`
- Sonarr: `http://baymax:8989`
- Radarr: `http://baymax:7878`
- slskd: `http://baymax:5030`, which needs
  `just secret secrets/services/slskd.yaml` to exist before it is enabled
- Navidrome: `http://baymax:4533`
- immich: `http://baymax:2283`

They also have names under `huxe.eu`, which Wall-E serves by proxying over
Tailscale: `https://pics.huxe.eu` and `https://stream.huxe.eu` are public,
and `https://<service>.huxe.eu` for the other seven is served only to clients on
the tailnet. Each name needs a Cloudflare A/AAAA record pointing at Wall-E before
ACME can issue its certificate. Two settings stay in a WebUI: Jellyfin needs
Wall-E's tailnet address under *Known proxies* to see client addresses instead of
the proxy's, and qBittorrent needs its own name allowed by the host-header
validation above its port.

They keep their state under `/data/baymax/qt` and share the libraries and
download trees through the `media` group, which your user is in as well; the
trees were regrouped once and the command for it is in
`hosts/baymax/default.nix`.

Each of them owns its own secrets and its own view of the world: qBittorrent's
save paths and password, slskd's accounts, and everything Sonarr and Radarr keep
in their databases — indexers, download clients, root folders, quality profiles
and the hardlink switch. None of that is a config file a host can declare, so
Nix sets the port, the bind address and the data directory, and the WebUI keeps
the rest.

## Known gaps

- **Borg backups are not wired up.** `modules/nixos/services/borgbackup.nix`
  implements jobs, mirrors and receiver repositories, but no host defines any,
  so the module is inert. Wiring it up also needs `keys/borg/<name>.pub` to
  exist and the `secrets/services/` rule in `.sops.yaml` to match the nested
  `secrets/services/borg/<host>/…` paths the module expects.
- **Bitwarden SSH agent.** `user/eek/system/env.nix` still carries a `REPLACE-ME`
  socket path for the Bitwarden desktop agent on macOS.

See [TODO.md](TODO.md) for the scheduled work.
