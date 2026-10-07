{
  config,
  lib,
  self,
  ...
}:
let
  inherit (import ../../shared/lib.nix { inherit lib self; }) mkSecret mkServiceOption;

  cfg = config.toua.services.slskd;
in
{
  options.toua.services.slskd = mkServiceOption "slskd" {
    port = 5030;
    host = "0.0.0.0";
  }
  // {
    soulseekPort = lib.mkOption {
      type = lib.types.port;
      default = 50300;
      description = "Port slskd accepts incoming Soulseek connections on.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/slskd";
      description = ''
        slskd's application directory: the database, the logs, and by default
        the download directories below.
      '';
    };

    downloadsDir = lib.mkOption {
      type = lib.types.path;
      default = "${cfg.dataDir}/downloads";
      description = "Where finished downloads are kept.";
    };

    incompleteDir = lib.mkOption {
      type = lib.types.path;
      default = "${cfg.dataDir}/incomplete";
      description = "Where downloads in progress are kept.";
    };

    shares = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "Directories shared on the Soulseek network; the unit sees them read-only.";
    };
  };

  config = lib.mkIf cfg.enable {
    # slskd cannot create its own Soulseek account, so the credentials and the
    # WebUI login come from the environment file. That file holds one key, `env`,
    # whose value is the dotenv block — the same shape as `mediamanager-env`:
    #
    #   env: |
    #     SLSKD_SLSK_USERNAME=<soulseek username>
    #     SLSKD_SLSK_PASSWORD=<soulseek password>
    #     SLSKD_USERNAME=<webui username>
    #     SLSKD_PASSWORD=<webui password>
    #
    # The generated `slskd.yml` lives in the store, so the environment is the
    # only place these can be kept out of it. Create the file with
    # `just secret secrets/services/slskd.yaml` before enabling the service.
    sops.secrets.slskd-env = mkSecret {
      file = "slskd";
      key = "env";
      owner = config.services.slskd.user;
      group = config.services.slskd.group;
      mode = "400";
    };

    services.slskd = {
      enable = true;
      environmentFile = config.sops.secrets.slskd-env.path;
      openFirewall = true;

      settings = {
        web.port = cfg.port;
        soulseek.listen_port = cfg.soulseekPort;

        directories = {
          downloads = cfg.downloadsDir;
          incomplete = cfg.incompleteDir;
        };

        shares.directories = cfg.shares;
      };
    };

    # Upstream's `openFirewall` covers the Soulseek listen port alone, not the
    # WebUI, which is reached on the LAN like the other media services.
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    # The unit is started with `--app-dir /var/lib/slskd` and its StateDirectory
    # is the same, neither an option, so the data directory is bound over it.
    # StateDirectory is created before the namespace is entered and the bind
    # target follows the unit's writable paths.
    #
    # Upstream derives `ReadOnlyPaths` from the share paths with
    # `builtins.elemAt (builtins.split …) 1`, which returns a list per path and
    # cannot be rendered into a unit file, so the paths are passed through.
    systemd.services.slskd.serviceConfig = {
      BindPaths = [ "${cfg.dataDir}:/var/lib/slskd" ];
      ReadOnlyPaths = lib.mkForce cfg.shares;

      # Downloaded files land in the host's shared tree, where the group keeps
      # write access to the directories slskd creates.
      UMask = "002";
    };

    # The database and the downloads share this directory, so it is group-owned
    # rather than private: the host's media group reads downloads below it, and
    # the unit needs the download directories to exist for its `ReadWritePaths`.
    systemd.tmpfiles.settings."10-slskd" = lib.genAttrs [
      cfg.dataDir
      cfg.downloadsDir
      cfg.incompleteDir
    ] (_: {
      d = {
        user = "slskd";
        group = "media";
        mode = "2775";
      };
    });

    users.users.slskd.extraGroups = [ "media" ];
  };
}
