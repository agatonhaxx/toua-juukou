{
  imports = [
    # keep-sorted start
    ../profiles/mac.nix
    ../services
    ./brew
    ./hardware
    ./options.nix
    ./preferences
    ./security.nix
    ./system.nix
    ./tailscale.nix
    # keep-sorted end
  ];
}
