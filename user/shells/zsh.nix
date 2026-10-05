{ lib, osConfig, ... }:
{
  programs.zsh.enable = lib.mkDefault osConfig.toua.shells.zsh.enable;
}
