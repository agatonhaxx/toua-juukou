{ lib, osConfig, ... }:
{
  programs.jq.enable = lib.mkDefault osConfig.toua.programs.jq.enable;
}
