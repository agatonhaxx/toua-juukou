{ lib, osConfig, ... }:
{
  programs.atuin.enable = lib.mkDefault osConfig.toua.programs.atuin.enable;
}
