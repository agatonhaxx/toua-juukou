{ lib, ... }:
let
  inherit (import ../shared/lib.nix { inherit lib; }) importDir;
in
{
  # Services that run on every class. NixOS-only services live in
  # `modules/nixos/services/`, which the NixOS tree imports alongside this
  # directory, so Darwin picks up a new shared service without any list to
  # maintain.
  imports = importDir { dir = ./.; };
}
