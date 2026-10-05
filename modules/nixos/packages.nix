{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.toua;
  graphical = cfg.desktop.gnome.enable || cfg.desktop.niri.enable;
in
{
  # Packages the machine itself provides, not any user. Anything a user or a
  # script calls belongs in `modules/programs/*`, which also covers Darwin.
  environment.systemPackages = lib.optional graphical pkgs.xdg-utils;
}
