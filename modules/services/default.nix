{ lib, ... }:
let
  inherit (import ../shared/lib.nix { inherit lib; }) importDir;
in
{
  # Services that run on every class; `modules/nixos/services/` is imported
  # alongside this directory, so there is no list to maintain.
  imports = importDir { dir = ./.; };
}
