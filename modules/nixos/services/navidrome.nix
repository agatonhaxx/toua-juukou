{
  config,
  lib,
  ...
}:
let
  inherit (import ../../shared/lib.nix { inherit lib; }) mkServiceOption;

  cfg = config.toua.services.music;
in
{
  options.toua.services.music =
    mkServiceOption "music" {
      port = 4533;
      host = "0.0.0.0";
    }
    // {
      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/navidrome";
        description = "Directory for Navidrome's database, with its cache below it.";
      };

      musicDir = lib.mkOption {
        type = lib.types.path;
        default = "${cfg.dataDir}/music";
        description = "Root of the music library to scan.";
      };
    };

  config = lib.mkIf cfg.enable {
    services.navidrome = {
      enable = true;
      openFirewall = true;

      # The module binds all three folders into the unit itself and leaves an
      # existing music directory alone, which is what a shared library wants.
      settings = {
        Address = cfg.host;
        Port = cfg.port;
        DataFolder = cfg.dataDir;
        CacheFolder = "${cfg.dataDir}/cache";
        MusicFolder = cfg.musicDir;
      };
    };

    # The music library is part of the host's shared media tree, so it is
    # group-owned rather than Navidrome's own.
    users.users.navidrome.extraGroups = [ "media" ];
  };
}
