{ lib, osConfig, ... }:
{
  programs.k9s.enable = lib.mkDefault osConfig.toua.programs.k9s.enable;
}
