{
  config,
  pkgs,
  lib,
  ...
}:
{
  home = {
    sessionPath = [
      "$GOPATH/bin"
      "$CARGO_HOME/bin"
      "$PNPM_HOME"
      "$GHOSTTY_BIN_DIR"

      "${config.home.homeDirectory}/.local/bin"
    ];

    file = builtins.listToAttrs (
      builtins.map (name: {
        name = ".local/bin/${lib.removeSuffix ".sh" (builtins.baseNameOf name)}";
        value = {
          source = lib.getExe (
            pkgs.writeShellApplication {
              name = builtins.baseNameOf name;
              text = builtins.readFile ./${name};

              # Commands the scripts call, so they do not depend on a
              # system-wide copy. `git-pr.sh` uses openssl.
              runtimeInputs = [ pkgs.openssl ];

              bashOptions = [
                "errexit"
                "pipefail"
              ];
            }
          );
        };
      }) (builtins.filter (n: !lib.hasSuffix ".nix" n) (builtins.attrNames (builtins.readDir ./.)))
    );
  };
}
