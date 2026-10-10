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

  /**
    Import every `.nix` file in `dir` as a module.

    `default.nix` is always skipped, since the file that does the importing is
    usually the one sitting beside the others. `exclude` names any further file
    to skip, such as the `lib.nix` next to this one.

    Directory order is `builtins.readDir` order, so the modules do not need to
    be listed — and adding a file to the directory is enough to load it.

    # Type

    ```
    importDir :: { dir :: Path, exclude ? [ String ] } -> [ Path ]
    ```

    # Example

    ```nix
    { lib, ... }:
    let
      inherit (import ../shared/lib.nix { inherit lib; }) importDir;
    in
    {
      imports = importDir { dir = ./.; };
    }
    ```
  */
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

  # Users the host manages, keyed by username. The primary user is always
  # managed — it is the account the host's integrations assume — so it is
  # re-added after filtering and forced enabled. `homeModule` falls back to the
  # repo-wide default, user/eek, for a host that names a primary user without
  # listing it in `toua.users`; it matches the option default in
  # modules/shared/options.nix. A second user names their own tree.
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

  /**
    A quick way to create the standard service options under
    `toua.services.<name>`. Ported from the dotfiles repo.

    # Type

    ```
    mkServiceOption :: String -> AttrSet -> AttrSet
    ```
  */
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
    };

  /**
    A Radarr/Sonarr-style arr. The two differ only in their name and their
    default port, so the module is written once here: an HTTP service with a data
    directory of its own, which imports from a download tree into a library and
    therefore needs the `media` group and a group-writable umask.

    What each arr keeps in its database — indexers, download clients, root
    folders, quality profiles — is the WebUI's, as the service section of
    README.md describes.

    # Type

    ```
    mkArr :: { config :: AttrSet, name :: String, port :: Int } -> AttrSet
    ```
  */
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
            description = ''
              The arr's own directory: its database, its configuration and the API
              key it generates.
            '';
          };
        };

      config = lib.mkIf cfg.enable {
        services.${name} = {
          enable = true;
          openFirewall = true;
          dataDir = cfg.dataDir;

          # Exported as `<NAME>__<SECTION>__<KEY>` at every start and merged over
          # config.xml, the same shape as prowlarr's settings: everything else
          # the WebUI saves is the arr's.
          settings.server = {
            port = cfg.port;
            bindaddress = cfg.host;
          };
        };

        # The module creates the directory itself only while `dataDir` sits at
        # its default, so a host directory is made here. It holds the database
        # and the API key, so it stays private; the libraries and the download
        # tree it imports from are the ones the media group opens.
        systemd.tmpfiles.settings."10-${name}"."${cfg.dataDir}".d = {
          user = name;
          group = name;
          mode = "0700";
        };

        # An import writes beside the download it came from — a hardlink — and
        # renames it into the library, so both trees need this user in the group
        # that owns them. The umask is what keeps what it writes group-writable
        # for the download clients and for the user.
        #
        # `mkForce` because the module sets `UMask` itself, and unit settings
        # merge by equality rather than precedence: two different values are an
        # error.
        users.users.${name}.extraGroups = [ "media" ];
        systemd.services.${name}.serviceConfig.UMask = lib.mkForce "002";
      };
    };

  /**
    Shared requirements and Cloudflare certificate settings for a web service.
    Keep assertions outside the implementation guarded by `dependenciesEnabled`.
  */
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

  /**
    Point a `sops.secrets.<name>` definition at a file under `secrets/`.

    `file` is the file name without the `.yaml` extension. `dir` picks the
    subdirectory it lives in and defaults to `services`; pass `dir = ""` for a
    file at the top level of `secrets/`, such as `secrets/eek.yaml`.

    Every other argument is forwarded to the secret definition, so `owner`,
    `group`, `mode` and `key` all behave as `sops-nix` documents.

    # Type

    ```
    mkSecret :: AttrSet -> AttrSet
    ```

    # Example

    ```nix
    sops.secrets.tailscale-auth = mkSecret { file = "tailscale"; key = "auth-key"; };
    sops.secrets.user-password = mkSecret { file = "eek"; dir = ""; key = "password"; };
    ```
  */
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
