{
  lib,
  pkgs,
  config,
  ...
}:
{
  home.packages =
    lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && config.toua.programs.qbittorrent.enable)
      [
        pkgs.qbittorrent
      ];
}
