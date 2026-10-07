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
  options.toua.services.jellyfin = mkServiceOption "jellyfin" {
    port = 8096;

    # Reached over the LAN rather than through a proxy, so it listens on every
    # interface.
    host = "0.0.0.0";
  }
  // {
    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/jellyfin";
      description = ''
        Base directory for Jellyfin's own files. Its configuration, log and
        cache directories default to subdirectories of it, and the upstream
        module creates and owns all four.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.jellyfin = {
      enable = true;
      dataDir = cfg.dataDir;

      # `openFirewall` deliberately stays off: it assumes the default ports,
      # while the port below is the one this configuration was written against.
    };

    # Jellyfin's HTTP port and bind address are WebUI settings rather than
    # module options, so `cfg.host` and `cfg.port` are the declarative record of
    # where it is expected to listen — 8096, its first-run default — and the
    # WebUI has to be set to match. The two UDP ports are Jellyfin's client
    # discovery and DLNA broadcasts, which the TV clients need to find it.
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
