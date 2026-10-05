{
  lib,
  pkgs,
  osConfig,
  ...
}:
{
  home.packages = lib.mkIf osConfig.toua.programs.ffmpeg.enable [ pkgs.ffmpeg ];
}
