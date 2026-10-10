{
  config,
  lib,
  pkgs,
  ...
}:
{
  # MangoHud's own module, and its `home.packages` entry, are Linux-only; the
  # guard keeps a Darwin host that happens to select the group from evaluating
  # them. No settings: the overlay is configured per game, from the file its own
  # module writes.
  programs.mangohud.enable = lib.mkDefault (
    pkgs.stdenv.hostPlatform.isLinux && config.toua.programs.mangohud.enable
  );
}
