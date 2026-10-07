{ config, lib, ... }:
let
  cfg = config.toua.profiles.desktop;
  groups = import ../groups.nix;
  inherit (import ../shared/lib.nix { inherit lib; }) mkDefaults;
in
{
  options.toua.profiles.desktop.enable = lib.mkEnableOption "the desktop workstation machine profile";

  config.toua = lib.mkIf cfg.enable (
    lib.mkMerge [
      (mkDefaults groups.cli)
      (mkDefaults groups.gui)

      # Only the programs: the services under `media` need a data volume and a
      # group the services share, so a host opts into them.
      (mkDefaults { inherit (groups.media) programs; })
      (mkDefaults groups.network)
      (mkDefaults {
        programs.niri.enable = true;
        desktop.gnome.enable = true;
        desktop.niri.enable = true;
        displayManager.gdm.enable = true;
      })
    ]
  );
}
