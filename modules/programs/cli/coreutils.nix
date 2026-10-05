{
  lib,
  pkgs,
  osConfig,
  ...
}:
{
  home.packages = lib.mkIf osConfig.toua.programs.coreutils.enable [ pkgs.uutils-coreutils-noprefix ];
}
