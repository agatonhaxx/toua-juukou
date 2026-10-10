{ lib, ... }:
{
  imports = [
    # keep-sorted start
    # Declares the service options and holds the implementations both platforms
    # share, so it is imported here and by the darwin side.
    ../services
    ./bluetooth.nix
    ./desktop.nix
    ./gaming.nix
    ./options.nix
    ./packages.nix
    # The systemd implementations, which only NixOS has.
    ./services
    ./users.nix
    # keep-sorted end
  ];
  system.stateVersion = lib.mkDefault "26.05";
}
