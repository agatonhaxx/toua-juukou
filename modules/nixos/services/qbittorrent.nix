{
  config,
  lib,
  ...
}:
let
  inherit (import ../../shared/lib.nix { inherit lib; }) mkServiceOption;

  cfg = config.toua.services.qbittorrent;
in
{
  options.toua.services.qbittorrent =
    mkServiceOption "qbittorrent" {
      port = 8080;
      host = "0.0.0.0";
    }
    // {
      torrentingPort = lib.mkOption {
        type = lib.types.port;
        default = 6881;
        description = "Port qBittorrent accepts incoming BitTorrent connections on.";
      };

      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/qBittorrent";
        description = "Profile directory; the configuration goes in `<dataDir>/qBittorrent`.";
      };
    };

  config = lib.mkIf cfg.enable {
    services.qbittorrent = {
      enable = true;
      profileDir = cfg.dataDir;
      webuiPort = cfg.port;
      torrentingPort = cfg.torrentingPort;
      openFirewall = true;

      # Empty on purpose: setting it makes the module rewrite `qBittorrent.conf`
      # on every start, discarding what the WebUI saved.
      serverConfig = { };
    };

    # The shared download tree keeps group write access; the module has no option
    # for the umask, so the unit is reached directly.
    systemd.services.qbittorrent.serviceConfig.UMask = "002";

    # DHT and µTP traffic is UDP; the upstream module opens only the torrenting
    # port, and only over TCP.
    networking.firewall.allowedUDPPorts = [ cfg.torrentingPort ];

    users.users.qbittorrent.extraGroups = [ "media" ];
  };
}
