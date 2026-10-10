{
  lib,
  pkgs,
  config,
  ...
}:
{
  programs.discord = {
    enable = lib.mkDefault config.toua.programs.discord.enable;
    # The native application is installed through Homebrew on Darwin.
    package = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin null;
  };
}
