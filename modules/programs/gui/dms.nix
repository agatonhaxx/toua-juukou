{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  # Same gate as niri.nix: this is a shell for a Wayland session and its module
  # ships a systemd user service, so it is a Linux-only thing.
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
in
{
  # Imported unconditionally: in Home Manager `pkgs` is not an external module
  # argument, it only arrives through `config._module.args.pkgs`, so reading it
  # in `imports` — resolved while the module set is still being collected — is an
  # infinite recursion. Gating happens in `config` below instead.
  imports = [ inputs.dms.homeModules.dank-material-shell ];

  # The assertion stays outside `isLinux` on purpose: inside it, it would only
  # ever evaluate on the platform it checks for, and so never fire. It has to sit
  # in `config` all the same — a module that sets a top-level `config` may not
  # also declare options beside it, and `assertions` is one.
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = isLinux || !config.toua.programs.dms.enable;
          message = "toua.programs.dms.enable is only supported on Linux";
        }
      ];
    }

    (lib.mkIf isLinux {
      # Deliberately no `settings`: the module installs settings.json as a
      # read-only store symlink and DMS reads that as "nix owns this file" — every
      # toggle in its own Settings UI would stop saving, migrations included. The
      # settings, the niri fragments under ~/.config/niri/dms and the notification
      # rules stay runtime state, which is what the GUI expects to write.
      #
      # Nothing spawns DMS here either: its systemd service is bound to
      # `wayland.systemd.target`, which niri's own unit brings up, so a
      # `spawn-at-startup "dms run"` in niri/config.kdl would start a second one.
      programs.dank-material-shell = {
        enable = lib.mkDefault config.toua.programs.dms.enable;

        # Not optional, and off by default upstream: `enable` alone installs the
        # shell and starts nothing at all.
        systemd.enable = lib.mkDefault config.toua.programs.dms.enable;
      };
    })
  ];
}
