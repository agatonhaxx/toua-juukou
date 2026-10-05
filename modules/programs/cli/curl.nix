{
  lib,
  pkgs,
  osConfig,
  ...
}:
{
  home.packages = lib.mkIf osConfig.toua.programs.curl.enable [ pkgs.curl ];
}
