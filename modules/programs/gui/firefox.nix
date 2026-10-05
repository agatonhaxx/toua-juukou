{
  lib,
  osConfig,
  pkgs,
  ...
}:
{
  programs.firefox = {
    enable = lib.mkDefault osConfig.toua.programs.firefox.enable;
    # The native application is installed through Homebrew on Darwin.
    package = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin null;
  };
}
