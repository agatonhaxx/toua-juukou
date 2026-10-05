{ lib, osConfig, ... }:
{
  programs.ripgrep.enable = lib.mkDefault osConfig.toua.programs.ripgrep.enable;
}
