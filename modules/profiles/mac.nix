{ config, lib, ... }:
let
  cfg = config.toua.profiles.mac;
in
{
  options.toua.profiles.mac.enable = lib.mkEnableOption "the macOS workstation machine profile";
  config.toua = lib.mkIf cfg.enable {
    programs.defaults.enable = lib.mkDefault true;
    programs.gui.enable = lib.mkDefault true;
    shells.enable = lib.mkDefault true;
    services.defaults.enable = lib.mkDefault true;
    fonts.enable = lib.mkDefault true;
  };
}
