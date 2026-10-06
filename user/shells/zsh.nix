{ lib, config, ... }:
{
  programs.zsh.enable = lib.mkDefault config.toua.programs.zsh.enable;
}
