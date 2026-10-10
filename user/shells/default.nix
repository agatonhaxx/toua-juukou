{ lib, ... }:
let
  inherit (import ../../modules/shared/lib.nix { inherit lib; }) importDir;
in
{
  # One module per shell, shared by every user: each sets only the shell's
  # presence from `toua.programs.<shell>.enable`, never anything personal.
  imports = importDir { dir = ./.; };
}
