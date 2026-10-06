{ lib, config, ... }:
{
  imports = [
    # keep-sorted start
    ../modules/programs/cli
    ../modules/programs/gui
    ./agents
    ./options.nix
    ./shells
    # keep-sorted end
  ];

  programs.home-manager.enable = true;
  xdg.enable = lib.mkDefault true;
  fonts.fontconfig.enable = lib.mkDefault config.toua.fonts.enable;
}
