{ lib, ... }:
let
  inherit (import ../../modules/shared/lib.nix { inherit lib; }) importDir;
in
{
  # One module per shell, shared by every user. What they set is the shell's
  # presence, from the host's `toua.programs.<shell>.enable` — the same toggle
  # every other program has — and nothing personal. A user's own shell settings
  # are theirs, and live in that user's tree: `user/eek/shells`.
  imports = importDir { dir = ./.; };
}
