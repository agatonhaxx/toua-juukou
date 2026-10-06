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

### Structure / consistency

- `modules/darwin/options.nix` namespaces `toua.mac.*` while the Linux-only
  options are flat (`toua.email`, `toua.desktop.*`).
- `modules/shared/users.nix` and `user/default.nix` independently re-implement
  the managedUser + primaryUser union.

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
