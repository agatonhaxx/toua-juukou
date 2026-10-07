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
  options.toua.services.qbittorrent = mkServiceOption "qbittorrent" {
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
      description = ''
        Profile directory. The upstream module keeps the configuration in
        `<dataDir>/qBittorrent` and creates both directories itself.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.qbittorrent = {
      enable = true;
      profileDir = cfg.dataDir;
      webuiPort = cfg.port;
      torrentingPort = cfg.torrentingPort;
      openFirewall = true;

      # `serverConfig` stays empty on purpose: setting it makes the module
      # rewrite `qBittorrent.conf` from it on every start, which would discard
      # everything the WebUI saves. The WebUI password, the save paths and the
      # WebUI's own bind address are therefore the WebUI's to keep — `cfg.host`
      # and `cfg.port` record where it is expected to listen instead.
      serverConfig = { };
    };

    # Downloaded files land in the host's shared download tree, where the group
    # keeps write access to the directories qBittorrent creates. The module has
    # no option for it, so the unit is reached directly.
    systemd.services.qbittorrent.serviceConfig.UMask = "002";

    # DHT and µTP traffic is UDP; the upstream module opens only the torrenting
    # port, and only over TCP.
    networking.firewall.allowedUDPPorts = [ cfg.torrentingPort ];

    users.users.qbittorrent.extraGroups = [ "media" ];
  };
}
