{ config, lib, ... }:
{
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
