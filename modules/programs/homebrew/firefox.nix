{ config, lib, ... }:
{
  config = lib.mkIf config.toua.programs.firefox.enable {
    homebrew.casks = [ "firefox" ];

    environment.loginItems = {
      enable = true;
      items = [ "/Applications/Firefox.app" ];
    };
  };
}
