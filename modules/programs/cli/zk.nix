{ lib, osConfig, ... }:
{
  programs.zk.enable = lib.mkDefault osConfig.toua.programs.zk.enable;
}
