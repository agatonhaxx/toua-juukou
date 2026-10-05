{ config, lib, ... }:
let
  cfg = config.toua.profiles.headless;
in
{
  options.toua.profiles.headless.enable = lib.mkEnableOption "the headless machine profile";

  config.toua = lib.mkIf cfg.enable {
    programs.defaults.enable = lib.mkDefault true;
    programs.gui.enable = lib.mkDefault false;
    shells.enable = lib.mkDefault true;
    services.defaults.enable = lib.mkDefault true;
    fonts.enable = lib.mkDefault false;

    # Every infrastructure service this repo ships is defined here, so a
    # headless host gets the full stack unless it opts out. Workstation profiles
    # leave them off and enable what they need individually.
    services = {
      acme.enable = lib.mkDefault true;
      atuin.enable = lib.mkDefault true;
      borgbackup.enable = lib.mkDefault true;
      kanidm.enable = lib.mkDefault true;
      nginx.enable = lib.mkDefault true;
      vaultwarden.enable = lib.mkDefault true;
    };
  };
}
