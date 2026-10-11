# TODO

## Personal

- create the Borg key and the two sops secrets the `personal` job needs, then
  the `~/documents/personal` backup runs on its own — see
  `hosts/baymax/default.nix`

## Repo review leftovers

Lower-priority findings from a repo audit, not yet acted on. See
[Known gaps](README.md#known-gaps) for the gaps that are documented rather than
scheduled.

- `modules/nixos/services/borgbackup.nix` now runs one job: baymax's
  `~/documents/personal` exports to `repos.baymax` on wall-e. The other
  clients, the `mirrors` that would make the copies 3-2-1, and Wall-E's own
  service repositories are still undefined.
