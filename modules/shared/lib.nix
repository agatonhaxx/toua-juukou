{
  lib,
  # Only `mkSecret` needs the flake, so a module directory that wants nothing
  # but `importDir` can call this file with `lib` alone.
  self ? null,
}:
let
  inherit (lib)
    hasSuffix
    mkEnableOption
    mkOption
    types
    ;

  # Imports every `.nix` file in `dir`, minus `default.nix` and `exclude`.
  importDir =
    {
      dir,
      exclude ? [ ],
    }:
    let
      files = builtins.readDir dir;
      skip = [ "default.nix" ] ++ exclude;
    in
    map (name: dir + "/${name}") (
      builtins.filter (
        name: files.${name} == "regular" && hasSuffix ".nix" name && !builtins.elem name skip
      ) (builtins.attrNames files)
    );

  # Application toggles default to false; groups supply explicit configuration.
  mkEnableOptions =
    names:
    lib.genAttrs names (name: {
      enable = mkEnableOption name;
    });

  # Put priority on each leaf so a host can override individual group members.
  mkDefaults = lib.mapAttrsRecursive (_: value: lib.mkDefault value);

  mkProgramToggles =
    cfg: names:
    lib.genAttrs names (name: {
      enable = lib.mkDefault cfg.${name}.enable;
    });

  # Explicit mappings cover names such as yq -> yq-go.
  mkEnabledPackages =
    cfg: packages:
    lib.concatMap (name: lib.optional cfg.${name}.enable packages.${name}) (
      builtins.attrNames packages
    );

  # The primary user is always managed — forced enabled and re-added after
  # filtering — because the host's integrations assume that account exists.
  mkManagedUsers =
    toua:
    let
      enabled = lib.filterAttrs (_: user: user.enable or false) toua.users;
      primary = toua.users.${toua.primaryUser} or { };
    in
    enabled
    // {
      ${toua.primaryUser} = primary // {
        enable = true;
        homeModule = primary.homeModule or ../../user/eek;
      };
    };

  # Declares the standard `toua.services.<name>` options.
  mkServiceOption =
    name:
    {
      port ? 0,
      host ? "0.0.0.0",
      domain ? "",
    }:
    {
      enable = mkEnableOption "Enable the ${name} service";

      host = mkOption {
        type = types.str;
        default = host;
        description = "The host for the ${name} service";
      };

      port = mkOption {
        type = types.port;
        default = port;
        description = "The port for the ${name} service";
      };

      domain = mkOption {
        type = types.str;
        default = domain;
        description = "Domain name for the ${name} service";
      };

      # Set on a host that fronts this service through its own nginx — wall-e
      # fronting baymax's media services. The service itself is enabled where it
      # runs, so the fronting host sets only `proxy` and `domain`.
      proxy = mkOption {
        type = types.nullOr (
          types.submodule {
            options = {
              host = mkOption {
                type = types.str;
                example = "baymax";
                description = "Host running the service, as the fronting nginx reaches it — a Tailscale MagicDNS name for another machine.";
              };

              access = mkOption {
                type = types.enum [
                  "public"
                  "tailnet"
                ];
                default = "public";
                description = "Who may reach the vhost: everyone, or only clients on the tailnet.";
              };

              # On by default because immich and jellyfin push updates over a
              # websocket; for the services that do not, the headers are inert.
              websockets = mkOption {
                type = types.bool;
                default = true;
                description = "Pass Upgrade headers through the proxy.";
              };

              maxBodySize = mkOption {
                type = types.nullOr types.str;
                default = null;
                example = "5g";
                description = "nginx `client_max_body_size`; null keeps nginx's 1m default, which immich uploads exceed.";
              };

              extraConfig = mkOption {
                type = types.lines;
                default = "";
                description = "Extra nginx directives for the vhost's `/` location.";
              };
            };
          }
        );
        default = null;
        description = "Front this service through the local nginx, named by `domain`.";
      };
    };

  # A Radarr/Sonarr-style arr: HTTP service, data directory, `media` group and
  # a group-writable umask; its database stays the WebUI's.
  mkArr =
    {
      config,
      name,
      port,
    }:
    let
      cfg = config.toua.services.${name};
    in
    {
      options.toua.services.${name} =
        mkServiceOption name {
          # Upstream's default, and the port Prowlarr's App entry and the WebUI
          # expect.
          port = port;

          # Reached over the LAN rather than through a proxy, so it listens on
          # every interface.
          host = "0.0.0.0";
        }
        // {
          dataDir = mkOption {
            type = types.path;
            default = "/var/lib/${name}";
            description = "The arr's own directory: its database, configuration and API key.";
          };
        };

      config = lib.mkIf cfg.enable {
        services.${name} = {
          enable = true;
          openFirewall = true;
          dataDir = cfg.dataDir;

          # Exported as `<NAME>__<SECTION>__<KEY>` at every start and merged over
          # config.xml; everything else the WebUI saves stays the arr's.
          settings.server = {
            port = cfg.port;
            bindaddress = cfg.host;
          };
        };

        # The module only creates its default `dataDir`, so a host's own directory
        # is made here — 0700, since it holds the database and the API key.
        systemd.tmpfiles.settings."10-${name}"."${cfg.dataDir}".d = {
          user = name;
          group = name;
          mode = "0700";
        };

        # Imports need the `media` group and a group-writable umask; `mkForce`
        # because unit settings merge by equality rather than precedence.
        users.users.${name}.extraGroups = [ "media" ];
        systemd.services.${name}.serviceConfig.UMask = lib.mkForce "002";
      };
    };

  # Shared requirements and Cloudflare certificate settings for a web service.
  # Keep assertions outside the implementation guarded by `dependenciesEnabled`.
  mkWebService =
    { config, name }:
    let
      toua = config.toua;
    in
    {
      assertions = [
        {
          assertion = toua.domain != "";
          message = "toua.services.${name}.enable needs toua.domain for its service domain and certificate.";
        }
      ]
      ++
        map
          (dependency: {
            assertion = toua.services.${dependency}.enable;
            message = "toua.services.${name}.enable needs toua.services.${dependency}.enable.";
          })
          [
            "acme"
            "nginx"
          ];

      dependenciesEnabled = toua.services.acme.enable && toua.services.nginx.enable;

      certificate = {
        dnsProvider = "cloudflare";
        # lego loads the token file through a systemd credential.
        credentialFiles."CLOUDFLARE_DNS_API_TOKEN_FILE" = config.sops.secrets.cloudflare-dns-token.path;
        # nginx must be able to read certificates referenced by useACMEHost.
        group = "nginx";
      };
    };

  # Points a `sops.secrets.<name>` definition at a file under `secrets/`: `file`
  # is the name without `.yaml`, `dir` its subdirectory ("" for the top level).
  mkSecret =
    {
      file,
      dir ? "services",
      ...
    }@args:
    let
      args' = removeAttrs args [
        "file"
        "dir"
      ];

      path = if dir == "" then "secrets/${file}.yaml" else "secrets/${dir}/${file}.yaml";
    in
    {
      sopsFile = "${self}/${path}";
    }
    // args';
in
{
  inherit
    importDir
    mkArr
    mkDefaults
    mkEnableOptions
    mkEnabledPackages
    mkManagedUsers
    mkProgramToggles
    mkSecret
    mkServiceOption
    mkWebService
    ;
}
