{ config, lib, ... }:
{
  config = lib.mkIf config.toua.programs.kiwidesk.enable {
    homebrew = {
      taps = [
        {
          name = "kiwicanopy/tap";
          trusted = true;
        }
      ];
      casks = [ "kiwidesk" ];
    };

    environment.loginItems = {
      enable = true;
      items = [ "/Applications/KiwiDesk.app" ];
    };
  };
}
