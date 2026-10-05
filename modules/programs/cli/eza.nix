{ lib, osConfig, ... }:
{
  programs.eza.enable = lib.mkDefault osConfig.toua.programs.eza.enable;
}
