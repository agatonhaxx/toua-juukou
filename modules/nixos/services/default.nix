{ lib, ... }:
let
  inherit (import ../../shared/lib.nix { inherit lib; }) importDir;
in
{
  # Every sibling is NixOS-only: they configure `security.acme`,
  # `services.nginx` or systemd units, and read the NixOS-only `toua.domain`.
  # Loading them off NixOS is an evaluation error, which is why they live under
  # the NixOS tree rather than beside the shared services.
  imports = importDir { dir = ./.; };
}
