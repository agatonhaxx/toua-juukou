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
        description = "Prowlarr's own directory: its configuration, database and API key.";
      };
    };

  config = lib.mkIf cfg.enable {
    # No `media` group, unlike its siblings: Prowlarr only serves indexers, and
    # systemd chowns the bind-mounted dataDir to its dynamic user at every start.
    services.prowlarr = {
      enable = true;
      openFirewall = true;
      dataDir = cfg.dataDir;

      # Exported as `PROWLARR__<SECTION>__<KEY>` at every start and merged over
      # the config file; everything else the WebUI saves stays Prowlarr's.
      settings.server = {
        port = cfg.port;
        bindaddress = cfg.host;
      };
    };
  };
}
