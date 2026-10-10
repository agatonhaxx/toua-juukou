{
  config,
  lib,
  ...
}:
let
  inherit (import ../../shared/lib.nix { inherit lib; }) importDir mkProgramToggles;
in
{
  # One module per graphical application; `importDir` skips this file, so they
  # are imported here.
  imports = importDir { dir = ./.; };

  # Only wezterm here: every other GUI program is configured by its own module
  # beside this one, which carries its toggle itself.
  programs = mkProgramToggles config.toua.programs [ "wezterm" ];
}
