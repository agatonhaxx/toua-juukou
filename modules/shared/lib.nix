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
    mkDefaults
    mkEnableOptions
    mkEnabledPackages
    mkProgramToggles
    mkSecret
    mkServiceOption
    mkWebService
    ;
}
