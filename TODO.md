# TODO

## Personal

- remove caps entirely from esc
- fix scroll
- caldav on wall-e radicale or baikal
- calino on phone
- dank calendar on desktop?
- chromium settings
- vicinae on linux instead of fuzzy and dms thingy
- bookmarks, calendar and contacts backup via borgbackup
- wayshot + Mod+Print -> dms screenshot ipc, once dms is running

## Repo review leftovers

Lower-priority findings from a repo audit, not yet acted on. See
[Known gaps](README.md#known-gaps) for the gaps that are documented rather than
scheduled.

- `modules/nixos/services/borgbackup.nix` is wired up but inert. The module is
  live — `modules/groups.nix` enables it and every host that selects the `server`
  group applies it — so the work is not deleting it but defining the
  `jobs`/`repos`/`mirrors` it emits nothing without.
