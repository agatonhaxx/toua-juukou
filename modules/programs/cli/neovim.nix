{ lib, osConfig, ... }:
{
  programs.neovim.enable = lib.mkDefault osConfig.toua.programs.neovim.enable;
}
