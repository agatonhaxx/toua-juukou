{
  imports = [
    # keep-sorted start
    ./bash.nix
    ./fish.nix
    ./zsh.nix
    # keep-sorted end
  ];

  home.shellAliases = {
    "cat" = "bat";
    "lg" = "lazygit";
  };
}
