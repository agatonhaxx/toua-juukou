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
  options.toua.services.slskd =
    mkServiceOption "slskd" {
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
        description = "slskd's application directory: the database and the logs.";
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
    # slskd cannot create its own account and its generated `slskd.yml` is in
    # the store, so the credentials live in `secrets/services/slskd.yaml`.
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

    # The app directory is not an option, so data is bound over it; the force is
    # because upstream derives `ReadOnlyPaths` in a way systemd cannot render.
    systemd.services.slskd.serviceConfig = {
      BindPaths = [ "${cfg.dataDir}:/var/lib/slskd" ];
      ReadOnlyPaths = lib.mkForce cfg.shares;

      # Downloaded files land in the host's shared tree, where the group keeps
      # write access to the directories slskd creates.
      UMask = "002";
    };

    # The database and the downloads share this directory, so it is group-owned:
    # the media group reads downloads below it and the unit needs them to exist.
    systemd.tmpfiles.settings."10-slskd" =
      lib.genAttrs
        [
          cfg.dataDir
          cfg.downloadsDir
          cfg.incompleteDir
        ]
        (_: {
          d = {
            user = "slskd";
            group = "media";
            mode = "2775";
          };
        });

    users.users.slskd.extraGroups = [ "media" ];
  };
}
