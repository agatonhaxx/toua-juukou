{ lib, ... }:
let
  inherit (import ../../../modules/shared/lib.nix { inherit lib; }) importDir;
in
{
  imports = importDir { dir = ./.; };

  home.shellAliases = {
    "cat" = "bat";
    "lg" = "lazygit";
  };
}
