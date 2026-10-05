{
  config,
  ...
}:
{
  imports = [
    # keep-sorted start
    ./nix.nix
    ./options.nix
    ./secrets.nix
    ./users.nix
    # keep-sorted end
  ];
  programs.fish.enable = true;
  programs.fish.useBabelfish = true;

  # Both NixOS and nix-darwin declare this option, so it can be set from the
  # shared module rather than repeated per platform.
  time.timeZone = config.toua.timeZone;
}
