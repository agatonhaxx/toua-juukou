{ lib, osConfig, ... }:
{
  programs.bash.enable = lib.mkDefault osConfig.toua.shells.bash.enable;
}
