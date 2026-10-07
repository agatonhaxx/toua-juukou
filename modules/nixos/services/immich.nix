{
  config,
  lib,
  ...
}:
let
  inherit (import ../../shared/lib.nix { inherit lib; }) mkServiceOption;

  cfg = config.toua.services.immich;
in
{
  options.toua.services.immich = mkServiceOption "immich" {
    port = 2283;
    host = "0.0.0.0";
  }
  // {
    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/immich";
      description = ''
        Media location: the original uploads and everything derived from them.
        The database lives in PostgreSQL instead, and the machine-learning model
        cache stays in the unit's `CacheDirectory`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.immich = {
      enable = true;
      host = cfg.host;
      port = cfg.port;
      mediaLocation = cfg.dataDir;
      openFirewall = true;
    };

    # The module only corrects the mode of an existing media location — media
    # written by older releases was world-readable — so the directory itself is
    # created here, with the mode the module enforces.
    systemd.tmpfiles.settings."10-immich" = {
      "${cfg.dataDir}"."d" = {
        user = config.services.immich.user;
        group = config.services.immich.group;
        mode = "0700";
      };
    };

    # Not needed for its own library, which it owns; it is what lets immich read
    # the shared libraries as external libraries.
    users.users.immich.extraGroups = [ "media" ];
  };
}
