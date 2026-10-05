{ lib, osConfig, ... }:
{
  programs.gpg.enable = lib.mkDefault osConfig.toua.programs.gnupg.enable;
}
