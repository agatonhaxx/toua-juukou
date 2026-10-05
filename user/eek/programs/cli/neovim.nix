{
  inputs,
  lib,
  osConfig,
  ...
}:
{
  imports = [
    inputs.nvim-eek.homeManagerModules.default
  ];

  # nvim-eek provides its own launcher and installation.
  programs.neovim.enable = false;
  programs.nvim-eek.enable = lib.mkDefault osConfig.toua.programs.neovim.enable;
}
