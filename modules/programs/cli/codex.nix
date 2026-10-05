{ lib, osConfig, ... }:
{
  programs.codex.enable = lib.mkDefault osConfig.toua.programs.codex.enable;
}
