{ lib, ... }:
let
  inherit (import ../../shared/lib.nix { inherit lib; }) importDir;
in
{
  # NixOS-only — they configure `security.acme`, nginx and systemd units — which
  # is why they live here rather than beside the shared services.
  imports = importDir { dir = ./.; };
}
