{ config, lib, ... }:
let
  inherit (import ../../shared/lib.nix { inherit lib; }) mkProgramToggles;
in
{
  programs = mkProgramToggles config.toua.programs [ "wezterm" ];
}
