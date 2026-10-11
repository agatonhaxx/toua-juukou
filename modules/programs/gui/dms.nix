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

      # What the shell reaches for while it runs.
      #
      # adw-gtk3 is the theme DMS writes its own colors into: `scripts/gtk.sh`
      # looks for `adw-gtk3{,-dark}/gtk-3.0` under the XDG_DATA_DIRS theme roots,
      # copies the one it finds into ~/.local/share/themes and patches that
      # copy. Without the package it warns "No user version of adw-gtk3 found"
      # and falls back to a single global override.
      #
      # ddcutil and i2c-tools are the DDC/CI side, for inspecting by hand the bus
      # that DMS itself drives over /dev/i2c-N. The devices come from
      # `hardware.i2c.enable` in modules/nixos/desktop.nix.
      #
      # hicolor-icon-theme is what makes the shell able to find icons by name.
      # Qt resolves a name only inside a theme directory that carries an
      # index.theme, and the shell runs on hicolor: every app that ships an icon
      # drops it in `share/icons/hicolor/<size>/apps` of *this* profile. Without
      # the package the profile has no index.theme, so Qt instantiates hicolor
      # from /run/current-system/sw and searches only system icons — which is why
      # a tray icon owned by a profile package (vicinae) warns "Could not load
      # icon" and draws nothing, while system icons resolve.
      home.packages = lib.mkIf config.toua.programs.dms.enable [
        pkgs.adw-gtk3
        pkgs.ddcutil
        pkgs.hicolor-icon-theme
        pkgs.i2c-tools
      ];

      # DMS themes Qt by putting the GTK3 platform theme — which reads the same
      # adw-gtk3 stylesheet DMS patches — in front of Qt6 apps; nixpkgs' qtbase
      # builds that plugin (`libqgtk3.so`). Qt5 keeps qt5ct, which is what
      # `qt.platformTheme.name` already selects.
      #
      # The unversioned variable is `mkDefault` on purpose: home-manager's qt
      # module assigns it plainly from `qt.platformTheme.name`, which is "qtct"
      # here and maps to "qt5ct" through that module's `styleNames`, and two
      # plain definitions of one key are a conflict rather than an override.
      home.sessionVariables = lib.mkIf config.toua.programs.dms.enable {
        QT_QPA_PLATFORMTHEME = lib.mkDefault "gtk3";
        QT_QPA_PLATFORMTHEME_QT6 = "gtk3";
      };

      # Home Manager keeps sessionVariables and the systemd user manager's
      # environment apart, and the shell is one of those services: without this
      # the variable its own Qt theming check reads would be missing.
      systemd.user.sessionVariables.QT_QPA_PLATFORMTHEME_QT6 = lib.mkIf config.toua.programs.dms.enable "gtk3";
    })
  ];
}
