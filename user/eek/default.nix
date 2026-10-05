{
  imports = [
    # keep-sorted start
    ../home.nix
    ./catppuccin.nix
    ./programs/cli
    ./programs/gui
    ./scripts
    ./shells
    ./system
    # keep-sorted end
  ];

  accounts.calendar.basePath = null;
}
