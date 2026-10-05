{ lib, ... }:
let
  inherit (lib) mkEnableOption;
in
{
  # macOS-only options, declared here for the same reason the NixOS-only ones
  # live under `modules/nixos/`: they do not exist on other platforms, so a
  # host cannot set them and be silently ignored.
  options.toua.mac = {
    homebrew.enable = mkEnableOption "Manage Homebrew with nix-homebrew" // {
      default = true;
    };
  };
}
