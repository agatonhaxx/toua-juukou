{ lib, osConfig, ... }:
{
  programs.bat.enable = lib.mkDefault osConfig.toua.programs.bat.enable;
}
