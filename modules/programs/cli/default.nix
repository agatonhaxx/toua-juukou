{ lib, ... }:
let
  inherit (import ../../shared/lib.nix { inherit lib; }) importDir;
in
{
  imports = importDir { dir = ./.; };
}
