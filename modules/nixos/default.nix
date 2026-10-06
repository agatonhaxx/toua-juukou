{ lib, ... }:
{
  imports = [
    # keep-sorted start
    ../profiles/desktop.nix
    ../profiles/headless.nix
    ../profiles/wsl.nix
    ../services
    ./bluetooth.nix
    ./desktop.nix
    ./options.nix
    ./packages.nix
    ./services
    ./users.nix
    # keep-sorted end
  ];
  system.stateVersion = lib.mkDefault "26.05";
}
