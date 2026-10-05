{ config, lib, ... }:
let
  cfg = config.toua.profiles.desktop;
in
{
  options.toua.profiles.desktop.enable = lib.mkEnableOption "the desktop workstation machine profile";

  config.toua = lib.mkIf cfg.enable {
    programs.defaults.enable = lib.mkDefault true;
    programs.gui.enable = lib.mkDefault true;
    shells.enable = lib.mkDefault true;
    services.defaults.enable = lib.mkDefault true;
    programs.niri.enable = lib.mkDefault true;
    fonts.enable = lib.mkDefault true;
  };
}
