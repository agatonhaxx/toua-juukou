# TODO

## Repo review leftovers

Lower-priority findings from a repo audit, not yet acted on. See
[Known gaps](README.md#known-gaps) for the gaps that are documented rather than
scheduled.

- `modules/nixos/services/borgbackup.nix` now runs one job: baymax's
  `~/documents/personal` exports to `repos.baymax` on wall-e. The other
  clients, the `mirrors` that would make the copies 3-2-1, and Wall-E's own
  service repositories are still undefined.
