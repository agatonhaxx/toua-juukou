{
  lib,
  pkgs,
  osConfig,
  ...
}:
{
  home.packages = lib.mkIf osConfig.toua.programs.dust.enable [ pkgs.dust ];
}
