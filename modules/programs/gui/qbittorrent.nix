{
  lib,
  pkgs,
  osConfig,
  ...
}:
{
  home.packages =
    lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && osConfig.toua.programs.qbittorrent.enable)
      [
        pkgs.qbittorrent
      ];
}
