{
  lib,
  osConfig,
  pkgs,
  ...
}:
{
  programs.chromium = {
    enable = lib.mkDefault osConfig.toua.programs.chromium.enable;
    # Chromium's Nix package is Linux-only; Darwin uses the native cask.
    package = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin null;
  };
}
