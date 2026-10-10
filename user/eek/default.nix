{
  # eek's Home Manager tree, layered on top of `user/home.nix` and
  # `user/shells`; a host names it as the `homeModule` for this user.
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
