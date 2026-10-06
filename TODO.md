# TODO

## Personal

- no pre commit!
- remove caps entirely from esc
- fix wallpaper repo as input
- fix monitor settings niri
- fix scroll
- check isabekk for gaming settings
- media services

## Repo review leftovers

Lower-priority findings from a repo audit, not yet acted on. See
[Known gaps](README.md#known-gaps) for the gaps that are documented rather than
scheduled.

### Bugs / coupling

- `mediaAssociations` registers `mpv.desktop` in `user/eek/system/xdg.nix`, but
  mpv is installed by the separate `toua.programs.mpv.enable`. With
  `mediaAssociations=true` and `mpv=false` the MIME entries point at a file that
  is not installed. The block also sits under `gui.enable`, so
  `mediaAssociations=true, gui=false` silently no-ops.
- `sops.secrets.cloudflare-dns-token` is declared only under `acme.enable` but
  dereferenced by `atuin.nix`, `kanidm.nix`, and `vaultwarden.nix` with no
  assertion, so enabling one of those without acme is an eval error. Same shape
  for `services.nginx.virtualHosts` versus `nginx.enable`.
- `toua.email` is documented as optional, but `acme.nix` asserts it non-null,
  `kanidm.nix` hardcodes the addresses anyway, and `vaultwarden.nix` asserts it
  for a Kanidm identity it never reads.

### Wrong comments

- `modules/darwin/hardware/trackpad.nix:3` — "enable natural scrolling" sits
  above `swipescrolldirection = false`.
- `modules/darwin/hardware/trackpad.nix:18` — "enable three finger drag" sits
  above `TrackpadThreeFingerDrag = false`.
- `modules/darwin/preferences/finder.nix:19` — "hide the quit button" sits above
  `QuitMenuItem = true`.
- `modules/darwin/hardware/keyboard.nix:26` — "enable press and hold" sits above
  `ApplePressAndHoldEnabled = false`; `:7` comments the flag that is off.

### Redundancy

- `hosts/wall-e/default.nix` re-sets values the `headless` profile already
  defaults.
- `modules/profiles/{mac,wsl}.nix` set `niri.enable = mkDefault false`, already
  false in `options.nix`.
- `hosts/baymax/default.nix` sets `allowUnfree`, already global in
  `modules/shared/nix.nix`.
- `modules/shared/nix.nix` carries an empty `overlays = [ ];`.
- `hosts/mac/default.nix` sets `homebrew.enable` (already the default) and
  `gui.enable` (already set by `profiles/mac.nix`).
- `user/eek/programs/gui/chromium.nix` lists `AutofillPaymentCardBenefits` twice.
- `GNUPGHOME` is set through both `programs.gpg.homedir` and `sessionVariables`.
- acme-cert + nginx-vhost + `domain != ""` boilerplate repeats across
  atuin/kanidm/vaultwarden — a `lib.nix` factoring candidate.

### Structure / consistency

- Option declaration is split: `bitwarden`, `raycast`, and `sf-symbols`
  self-declare `toua.programs.*` in their homebrew modules while everything else
  is centralized in `options.nix`.
- `cliProgramNames` populates `toua.programs.defaults` — the list name does not
  match the group name.
- `modules/darwin/options.nix` namespaces `toua.mac.*` while the Linux-only
  options are flat (`toua.email`, `toua.desktop.*`).
- `user/shells/fish.nix` hardcodes `enable = true`, ignoring `toua.shells.*`
  that bash and zsh obey.
- `modules/shared/users.nix` and `user/default.nix` independently re-implement
  the managedUser + primaryUser union.
- `mkServiceOption` defaults enable to false, so `services.defaults` effectively
  controls only `tailscale`.

### Dead code / docs

- `modules/services/borgbackup.nix` is inert — covered by Known gaps, kept here
  as the wiring work.
- `modules/darwin/preferences/dock.nix` holds a commented block referencing
  `/Users/isabel/…` and an undefined `pkgs`.
- `user/agents/AGENTS.md` ends a sentence mid-word and says "Gorgejo" for
  "Forgejo".
- `modules/darwin/preferences/default.nix` has a header explaining
  `CustomUserPreferences` that the file no longer uses.
- `hosts/wall-e/default.nix` still says `.sops.yaml` does not list wall-e.
- Dead commented configuration in `user/eek/system/env.nix`, `hosts/bender`,
  `hosts/mac`, and `clock.nix`.
