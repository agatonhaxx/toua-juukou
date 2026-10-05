{ config, lib, ... }:
{
  options.toua.programs.raycast.enable = lib.mkEnableOption "the Raycast cask" // {
    default = config.toua.programs.gui.enable;
  };

  config = lib.mkIf config.toua.programs.raycast.enable {
    homebrew = {
      brews = [ "media-control" ];
      casks = [ "raycast" ];
    };

    environment.loginItems = {
      enable = true;
      items = [ "/Applications/Raycast.app" ];
    };
  };
}
