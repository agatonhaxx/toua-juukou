{ lib, osConfig, ... }:
{
  programs.starship.enable = lib.mkDefault osConfig.toua.programs.starship.enable;
}
