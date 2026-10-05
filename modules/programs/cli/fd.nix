{ lib, osConfig, ... }:
{
  programs.fd.enable = lib.mkDefault osConfig.toua.programs.fd.enable;
}
