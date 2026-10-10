{ config, lib, ... }:
let
  inherit (import ../../shared/lib.nix { inherit lib; }) mkArr;
in
mkArr {
  inherit config;
  name = "radarr";
  port = 7878;
}
