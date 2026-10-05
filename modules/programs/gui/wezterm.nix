{ lib, osConfig, ... }:
{
  programs.wezterm.enable = lib.mkDefault osConfig.toua.programs.wezterm.enable;
}
