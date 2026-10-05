{ lib, osConfig, ... }:
{
  programs.claude-code.enable = lib.mkDefault osConfig.toua.programs.claude-code.enable;
}
