{ lib, ... }:
let
  inherit (lib) mkEnableOption;
  inherit (import ../shared/lib.nix { inherit lib; }) mkEnableOptions;
  groups = import ../groups.nix;
in
{
  # macOS-only options, declared here for the same reason the NixOS-only ones
  # live under `modules/nixos/`: they do not exist on other platforms, so a
  # host cannot set them and be silently ignored.
  options.toua.homebrew.enable = mkEnableOption "Manage Homebrew with nix-homebrew";
  options.toua.programs = mkEnableOptions (builtins.attrNames groups.mac.programs);
}
