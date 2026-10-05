{ lib, osConfig, ... }:
{
  programs.git.enable = lib.mkDefault osConfig.toua.programs.git.enable;
}
