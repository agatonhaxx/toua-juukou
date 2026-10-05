{
  lib,
  self,
}:
let
  inherit (lib) mkEnableOption mkOption types;

  /**
    A quick way to create the standard service options under
    `toua.services.<name>`. Ported from the dotfiles repo.

    # Type

    ```
    mkServiceOption :: String -> (Int -> String -> String -> AttrSet) -> AttrSet
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
        defaultText = "networking.domain";
        description = "Domain name for the ${name} service";
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
    mkSecret :: (String -> String -> AttrSet) -> AttrSet
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
  inherit mkSecret mkServiceOption;
}
