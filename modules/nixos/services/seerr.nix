{
  config,
  lib,
  ...
}:
let
  inherit (import ../../shared/lib.nix { inherit lib; }) mkServiceOption;

  cfg = config.toua.services.seerr;

  # `services.seerr` keeps its state at `/var/lib/seerr` and no bind-mount
  # option of its own, so a host with another volume needs the same arrangement
  # the arrs' modules carry.
  isCustomDataDir = cfg.dataDir != "/var/lib/seerr";
in
{
  options.toua.services.seerr =
    mkServiceOption "seerr" {
      # Jellyseerr's port, which Seerr kept.
      port = 5055;

      # Reached over the LAN rather than through a proxy. The module has no
      # bind-address setting, so this only records where it answers.
      host = "0.0.0.0";
    }
    // {
      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/seerr";
        description = "Backing directory for Seerr's configuration and database; the service still sees it at `/var/lib/seerr`.";
      };
    };

  config = lib.mkIf cfg.enable {
    # Jellyseerr and Overseerr merged into Seerr; a new install takes the merged
    # name, so there is nothing to migrate from `services.jellyseerr`.
    services.seerr = {
      enable = true;
      openFirewall = true;
      port = cfg.port;
    };

    # The upstream module creates and owns its default state directory. A host
    # directory is made here and mounted over the private state path, where
    # systemd's DynamicUser idmap makes it writable to the service.
    systemd.tmpfiles.settings."10-seerr".${cfg.dataDir}.d = lib.mkIf isCustomDataDir {
      user = "root";
      group = "root";
      mode = "0700";
    };

    systemd.mounts = lib.optional isCustomDataDir {
      what = cfg.dataDir;
      where = "/var/lib/private/seerr";
      options = "bind";
      wantedBy = [ "local-fs.target" ];
    };

    systemd.services.seerr.unitConfig.RequiresMountsFor = lib.mkIf isCustomDataDir [
      cfg.dataDir
    ];
  };
}
