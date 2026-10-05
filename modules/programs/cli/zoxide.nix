{ lib, osConfig, ... }:
{
  programs.zoxide.enable = lib.mkDefault osConfig.toua.programs.zoxide.enable;
}
