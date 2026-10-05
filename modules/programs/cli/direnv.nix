{ lib, osConfig, ... }:
{
  programs.direnv.enable = lib.mkDefault osConfig.toua.programs.direnv.enable;
}
