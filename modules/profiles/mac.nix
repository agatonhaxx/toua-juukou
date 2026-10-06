{ config, lib, ... }:
let
  cfg = config.toua.profiles.mac;
  groups = import ../groups.nix;
  inherit (import ../shared/lib.nix { inherit lib; }) mkDefaults;
in
{
  options.toua.profiles.mac.enable = lib.mkEnableOption "the macOS workstation machine profile";
  config.toua = lib.mkIf cfg.enable (
    lib.mkMerge [
      (mkDefaults groups.cli)
      (mkDefaults groups.gui)
      (mkDefaults groups.media)
      (mkDefaults groups.mac)
      (mkDefaults groups.network)
      (mkDefaults { homebrew.enable = true; })
    ]
  );
}
