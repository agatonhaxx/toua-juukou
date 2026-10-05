{ lib, osConfig, ... }:
{
  imports = [
    # keep-sorted start
    ../modules/programs/cli
    ../modules/programs/gui
    ./agents
    ./shells
    # keep-sorted end
  ];

  programs.home-manager.enable = true;
  xdg.enable = lib.mkDefault true;
  fonts.fontconfig.enable = lib.mkDefault osConfig.toua.fonts.enable;
}
