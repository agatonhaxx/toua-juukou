{ lib, osConfig, ... }:
{
  programs.yazi.enable = lib.mkDefault osConfig.toua.programs.yazi.enable;
}
