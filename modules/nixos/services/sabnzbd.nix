{
  config,
  lib,
  ...
}:
let
  inherit (import ../../shared/lib.nix { inherit lib; }) mkServiceOption;

  cfg = config.toua.services.sabnzbd;

  # The ini path and the unit's StateDirectory are both `/var/lib/<stateDir>`,
  # and neither takes an absolute path.
  stateDir = config.services.sabnzbd.stateDir;
in
{
  options.toua.services.sabnzbd =
    mkServiceOption "sabnzbd" {
      # Upstream defaults to 8080, which the qBittorrent WebUI already holds.
      port = 8081;
      host = "0.0.0.0";
    }
    // {
      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/sabnzbd";
        description = "Directory holding `sabnzbd.ini`.";
      };

      incompleteDir = lib.mkOption {
        type = lib.types.path;
        default = "${cfg.dataDir}/incomplete";
        description = "Where sabnzbd assembles downloads (`misc.download_dir`).";
      };

      completeDir = lib.mkOption {
        type = lib.types.path;
        default = "${cfg.dataDir}/complete";
        description = "Where finished downloads are moved (`misc.complete_dir`).";
      };
    };

  config = lib.mkIf cfg.enable {
    services.sabnzbd = {
      enable = true;
      openFirewall = true;

      settings.misc = {
        host = cfg.host;
        port = cfg.port;
        download_dir = cfg.incompleteDir;
        complete_dir = cfg.completeDir;
      };

      # The WebUI keeps its indexers, news servers and API key in the ini it
      # generates; left off, the module writes it read-only and those saves go.
      allowConfigWrite = true;
    };

    # The unit works from `/var/lib/<stateDir>` with no option to move it, so the
    # data directory is bound over it.
    systemd.services.sabnzbd.serviceConfig.BindPaths = [ "${cfg.dataDir}:/var/lib/${stateDir}" ];

    # The module creates nothing itself: the ini directory is sabnzbd's own, and
    # the download directories are group-owned setgid like the shared tree.
    systemd.tmpfiles.settings."10-sabnzbd" = {
      "${cfg.dataDir}"."d" = {
        user = "sabnzbd";
        group = "sabnzbd";
        mode = "0700";
      };

      "${cfg.incompleteDir}"."d" = {
        user = "sabnzbd";
        group = "media";
        mode = "2775";
      };

      "${cfg.completeDir}"."d" = {
        user = "sabnzbd";
        group = "media";
        mode = "2775";
      };
    };

    users.users.sabnzbd.extraGroups = [ "media" ];
  };
}
