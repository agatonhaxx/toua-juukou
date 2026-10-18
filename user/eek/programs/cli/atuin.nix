{
  lib,
  config,
  ...
}:
{
  programs.atuin = lib.mkIf config.programs.atuin.enable {
    settings = {
      inline_height = 0;
      auto_sync = true;
      sync_frequency = "5m";
      sync_address = "https://atuin.huxe.eu";
      search_mode = "prefix";
    };
  };
}
