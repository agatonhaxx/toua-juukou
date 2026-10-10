{
  config,
  lib,
  ...
}:
let
  inherit (import ../../shared/lib.nix { inherit lib; }) mkServiceOption;

  cfg = config.toua.services.jellyfin;
in
{
  options.toua.services.jellyfin =
    mkServiceOption "jellyfin" {
      port = 8096;

      # Reached over the LAN rather than through a proxy, so it listens on every
      # interface.
      host = "0.0.0.0";
    }
    // {
      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/jellyfin";
        description = "Jellyfin's own files; the upstream module creates and owns its config, log and cache subdirectories.";
      };
    };

  config = lib.mkIf cfg.enable {
    services.jellyfin = {
      enable = true;
      dataDir = cfg.dataDir;

      # `openFirewall` deliberately stays off: it assumes the default ports,
      # while the port below is the one this configuration was written against.
    };

    # Port and bind address are WebUI settings, so `cfg.port` only records where
    # it is expected to listen; the UDP ports are DLNA discovery for TV clients.
    networking.firewall = {
      allowedTCPPorts = [ cfg.port ];
      allowedUDPPorts = [
        1900
        7359
      ];
    };

    # The libraries live in the host's shared media tree, which is group-owned
    # so that every media service can read it.
    users.users.jellyfin.extraGroups = [ "media" ];
  };
}
