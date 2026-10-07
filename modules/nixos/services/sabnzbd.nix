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
  options.toua.services.sabnzbd = mkServiceOption "sabnzbd" {
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
      description = ''
        Where finished downloads are moved (`misc.complete_dir`). The category
        directories below it are the WebUI's to arrange.
      '';
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

      # sabnzbd generates the ini itself, so the WebUI keeps its indexers, news
      # servers and API key there, and the settings above are merged over
      # whatever it holds at every start. Left off, the module writes the ini
      # read-only and the WebUI's saves would be lost.
      allowConfigWrite = true;
    };

    # The unit works from `/var/lib/<stateDir>` with no option to move it, so the
    # data directory is bound over it. StateDirectory is created before the
    # namespace is entered and the bind target follows the unit's writable paths.
    systemd.services.sabnzbd.serviceConfig.BindPaths = [ "${cfg.dataDir}:/var/lib/${stateDir}" ];

    # The upstream module creates nothing itself. The ini directory is
    # sabnzbd's own; the download directories belong to the host's shared
    # download tree, so they are group-owned and setgid, which is also what
    # keeps the group on what sabnzbd writes into them.
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
