{
  imports = [
    # keep-sorted start
    ../profiles/mac.nix
    ../programs/gui/flow.nix
    ../services
    ./brew
    ./hardware
    ./options.nix
    ./preferences
    ./security.nix
    ./system.nix
    # keep-sorted end
  ];
}
