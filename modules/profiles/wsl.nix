{ config, lib, ... }:
let
  cfg = config.toua.profiles.wsl;
  groups = import ../groups.nix;
  inherit (import ../shared/lib.nix { inherit lib; }) mkDefaults;
in
{
  options.toua.profiles.wsl.enable = lib.mkEnableOption "the WSL development machine profile";

  config.toua = lib.mkIf cfg.enable (
    lib.mkMerge [
      (mkDefaults groups.cli)
      (mkDefaults groups.network)
    ]
  );
}
