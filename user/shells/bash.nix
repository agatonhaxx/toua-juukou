{ lib, config, ... }:
{
  programs.bash.enable = lib.mkDefault config.toua.programs.bash.enable;
}
