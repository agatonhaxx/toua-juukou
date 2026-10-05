{ config, lib, ... }:
let
  cfg = config.toua.profiles.wsl;
in
{
  options.toua.profiles.wsl.enable = lib.mkEnableOption "the WSL development machine profile";

  config.toua = lib.mkIf cfg.enable {
    programs.defaults.enable = lib.mkDefault true;
    programs.gui.enable = lib.mkDefault false;
    shells.enable = lib.mkDefault true;
    services.defaults.enable = lib.mkDefault true;
    fonts.enable = lib.mkDefault false;
    programs.niri.enable = lib.mkDefault false;
  };
}
