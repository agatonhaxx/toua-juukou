{
  config,
  inputs,
  lib,
  self,
  ...
}:
let
  inherit (import ../../shared/lib.nix { inherit lib self; }) mkSecret mkServiceOption;

  cfg = config.toua.services.mediamanager;

  # The upstream module treats these four as the directories MediaManager owns,
  # and reads them back for the unit's `RequiresMountsFor`. It never creates
  # them, so the tmpfiles rule below does.
  mediaDirs = config.services.media-manager.settings.misc;
in
{
  imports = [ inputs.mediamanager-nix.nixosModules.default ];

  options.toua.services.mediamanager = mkServiceOption "mediamanager" {
    port = 8000;

    # No nginx in front of this one, so nothing else narrows the bind for us.
    # It is reached on the LAN, or through an SSH tunnel from off it.
    host = "127.0.0.1";
  }
  // {
    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/media-manager/media";
      description = ''
        Root for MediaManager's own files. The library paths default to
        subdirectories of it; point `services.media-manager.settings.misc` at
        the real media instead of leaving them here.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # MediaManager writes a random token secret on every start unless the
    # environment supplies one, which would sign everyone out whenever the
    # service restarts. The secret file holds one key, `env`, whose value is the
    # dotenv block written out as the environment file — the same shape
    # `vaultwarden-env` uses:
    #
    #   env: |
    #     MEDIAMANAGER_AUTH__TOKEN_SECRET=<openssl rand -hex 64>
    #
    # The rest of the settings go through the generated TOML instead, so this is
    # the only variable here; `MEDIAMANAGER_` plus the config path with `__` per
    # level is how anything else that must stay out of the Nix store is added.
    sops.secrets.mediamanager-env = mkSecret {
      file = "mediamanager";
      key = "env";
      owner = config.services.media-manager.user;
      group = config.services.media-manager.group;
      mode = "400";
    };

    services.media-manager = {
      enable = true;
      host = cfg.host;
      port = cfg.port;
      dataDir = cfg.dataDir;
      environmentFile = config.sops.secrets.mediamanager-env.path;

      # Same host, same unix socket, so the database needs no password: the
      # service user is the database user and authenticates by peer.
      postgres.enable = true;

      settings = {
        # Note the trailing-slash-free form; MediaManager rejects the other.
        misc = {
          frontend_url = "http://${cfg.host}:${toString cfg.port}";
          cors_urls = [ "http://${cfg.host}:${toString cfg.port}" ];
        };

        # `auth.admin_emails` is deliberately absent too: it is what makes the
        # first account an administrator, so it is the host's to set rather
        # than a placeholder to inherit.

        # The integration blocks below are the shape of each client, taken from
        # upstream's config.example.toml and left switched off. Passwords are
        # absent on purpose: they belong in the environment file, whose naming
        # scheme is MEDIAMANAGER_ plus the path with `__` for each level, e.g.
        # MEDIAMANAGER_TORRENTS__QBITTORRENT__PASSWORD.
        torrents = {
          qbittorrent = {
            enabled = false;
            host = "http://localhost";
            port = 8080;
            username = "admin";
          };

          transmission = {
            enabled = false;
            host = "localhost";
            port = 9091;
            username = "admin";
            https_enabled = true;
            path = "/transmission/rpc";
          };

          sabnzbd = {
            enabled = false;
            host = "http://localhost";
            port = 8080;
            api_key = "";
            base_path = "/api";
          };
        };

        indexers = {
          prowlarr = {
            enabled = false;
            url = "http://localhost:9696";
            api_key = "";
            timeout_seconds = 60;
          };

          jackett = {
            enabled = false;
            url = "http://localhost:9117";
            api_key = "";
            indexers = [ ];
            timeout_seconds = 60;
          };
        };
      };
    };

    # MediaManager is pointed at libraries that usually live on the data disks,
    # and it does not make them itself. Creating them here rather than inside
    # the upstream module keeps them owned by the service user wherever they
    # are pointed — which also means an existing library directory is chowned
    # to the service user, so give it a fresh path if that is not wanted.
    systemd.tmpfiles.settings."10-mediamanager" = lib.genAttrs [
      mediaDirs.image_directory
      mediaDirs.tv_directory
      mediaDirs.movie_directory
      mediaDirs.torrent_directory
    ] (_: {
      d = {
        user = config.services.media-manager.user;
        group = config.services.media-manager.group;
        mode = "0755";
      };
    });
  };
}
