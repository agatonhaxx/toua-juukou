{
  lib,
  config,
  ...
}:
{
  programs.atuin = lib.mkIf config.programs.atuin.enable {
    settings = {
      inline_height = 0;
    };
  };
}
