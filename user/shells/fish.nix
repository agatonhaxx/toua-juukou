{
  lib,
  osConfig,
  pkgs,
  ...
}:
{
  programs.fish = {
    enable = lib.mkDefault osConfig.toua.shells.fish.enable;

    # Addresses $PATH re-ordering by Apple's `path_helper` tool, prioritising Apple’s tools over Nix ones.
    # https://github.com/LnL7/nix-darwin/issues/122
    loginShellInit =
      let
        # On NixOS, privileged commands such as sudo must resolve through the
        # setuid wrappers before their unprivileged system-profile binaries.
        profiles = [
          "/etc/profiles/per-user/$USER"
        ]
        ++ lib.optional pkgs.stdenv.hostPlatform.isLinux "/run/wrappers"
        ++ [
          "/run/current-system/sw"
        ];

        makeBinSearchPath = lib.concatMapStringsSep " " (path: ("\"" + "${path}/bin" + "\""));
      in
      ''
        fish_add_path --move --prepend --path ${makeBinSearchPath profiles}
        set fish_user_paths $fish_user_paths
      '';

  };
}
