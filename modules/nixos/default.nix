{ lib, ... }:
{
  imports = [
    # keep-sorted start
    ../profiles/desktop.nix
    ../profiles/headless.nix
    ../profiles/wsl.nix
    ../services/nixos.nix
    ./desktop.nix
    ./options.nix
    ./packages.nix
    ./users.nix
    # keep-sorted end
  ];
  system.stateVersion = lib.mkDefault "26.05";
}
