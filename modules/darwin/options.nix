{ lib, ... }:
let
  inherit (lib) mkEnableOption;
  inherit (import ../shared/lib.nix { inherit lib; }) mkEnableOptions;
  groups = import ../groups.nix;
in
{
  # macOS-only, declared here for the same reason the NixOS-only options live
  # under `modules/nixos/`: off-platform they do not exist.
  options.toua.homebrew.enable = mkEnableOption "Manage Homebrew with nix-homebrew";
  options.toua.programs = mkEnableOptions (builtins.attrNames groups.mac.programs);
}
