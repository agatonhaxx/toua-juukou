{ lib, osConfig, ... }:
{
  programs.navi.enable = lib.mkDefault osConfig.toua.programs.navi.enable;
}
