{ lib, osConfig, ... }:
{
  programs.mpv.enable = lib.mkDefault osConfig.toua.programs.mpv.enable;
}
