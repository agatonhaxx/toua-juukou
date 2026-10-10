{
  config,
  lib,
  ...
}:
let
  inherit (import ../../shared/lib.nix { inherit lib; }) mkServiceOption;

  cfg = config.toua.services.prowlarr;
in
{
  options.toua.services.prowlarr =
    mkServiceOption "prowlarr" {
      # Upstream's default, and the port the arrs and the WebUI expect.
      port = 9696;

      # Reached over the LAN rather than through a proxy, so it listens on every
      # interface.
      host = "0.0.0.0";
    }
    // {
      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/prowlarr";
        description = ''
          Prowlarr's own directory: its configuration, database and the API key
          it generates.
        '';
      };
    };

  config = lib.mkIf cfg.enable {
    # No `media` group here, unlike its siblings: Prowlarr reads no library and
    # writes no download, it only serves indexers to the clients. Its data
    # directory is its own, and the module creates it — a non-default `dataDir`
    # is bind-mounted over the unit's `/var/lib/private/prowlarr`, and systemd
    # chowns that to the unit's dynamic user at every start, which is what makes
    # the host directory writable.
    services.prowlarr = {
      enable = true;
      openFirewall = true;
      dataDir = cfg.dataDir;

      # These are exported as `PROWLARR__<SECTION>__<KEY>` at every start and
      # merged over the config file, the same shape as sabnzbd's settings: the
      # keys below are this file's, and everything else the WebUI saves is
      # Prowlarr's.
      settings.server = {
        port = cfg.port;
        bindaddress = cfg.host;
      };
    };
  };
}
