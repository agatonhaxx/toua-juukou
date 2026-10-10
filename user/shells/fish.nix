{
  lib,
  config,
  pkgs,
  ...
}:
{
  programs.fish = {
    enable = lib.mkDefault config.toua.programs.fish.enable;

    # Fish reads no /etc/profile, so this is the only thing that puts the
    # system profile directories on its PATH. It prepends them rather than
    # appending, so the Nix binaries win over anything a login script puts in
    # front later — on macOS that is `path_helper`, which hosts/mac/default.nix
    # describes.
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
