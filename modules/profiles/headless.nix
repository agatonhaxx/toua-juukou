{ config, lib, ... }:
let
  cfg = config.toua.profiles.headless;
  groups = import ../groups.nix;
  inherit (import ../shared/lib.nix { inherit lib; }) mkDefaults;
in
{
  options.toua.profiles.headless.enable = lib.mkEnableOption "the headless machine profile";

  config.toua = lib.mkIf cfg.enable (
    lib.mkMerge [
      (mkDefaults groups.cli)
      (mkDefaults groups.network)
      (mkDefaults groups.server)
    ]
  );
}
