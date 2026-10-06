{
  config,
  lib,
  pkgs,
  ...
}:
let
  associations = lib.genAttrs [
    "text/html"
    "application/pdf"
    "x-www-browser"
    "x-scheme-handler/http"
    "x-scheme-handler/https"
    "x-scheme-handler/ftp"
    "x-scheme-handler/about"
    "x-scheme-handler/unknown"
  ] (_: "chromium-browser.desktop");
in
{
  programs.chromium = {
    enable = lib.mkDefault config.toua.programs.chromium.enable;
    # Chromium's Nix package is Linux-only; Darwin uses the native cask.
    package = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin null;
  };

  xdg.mimeApps = lib.mkIf config.programs.chromium.enable {
    enable = true;
    associations.added = associations;
    defaultApplications = associations;
  };
}
