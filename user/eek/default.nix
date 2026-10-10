{
  # eek's Home Manager tree. `user/home.nix` is what every user gets and
  # `user/shells` is the setup the shells share; everything below is personal
  # and overrides them, which is why this tree is the `homeModule` a host names
  # for this user.
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
