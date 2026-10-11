{
  lib,
  config,
  inputs,
  pkgs,
  inputs',
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    mkOption
    types
    ;
in
{
  imports = [
    inputs.catppuccin.homeModules.catppuccin
  ];

  options.palette = mkOption {
    type = types.attrs;
  };

  config = mkMerge [
    {
      catppuccin = {
        flavor = "mocha";
        accent = "mauve";
        autoEnable = true;
        enable = true;

      };

      home.packages = mkIf config.catppuccin.enable [
        # keep-sorted start
        inputs'.catppuccin.packages.catwalk
        inputs'.catppuccin.packages.whiskers
        # keep-sorted end
      ];

      palette = lib.importJSON (config.catppuccin.sources.palette + "/palette.json");
    }

    (mkIf config.toua.graphical.enable {
      # Papirus icon theme for graphical applications.
      catppuccin.gtk.icon.enable = true;
      catppuccin.firefox.enable = false;
    })

    # qt5ct is not available on Darwin. The app gate also keeps Qt and its
    # configuration tools out of headless Linux hosts.
    (mkIf (pkgs.stdenv.hostPlatform.isLinux && config.toua.graphical.enable) {
      # Qt's appearance belongs to DMS: it rewrites ~/.config/qt5ct/qt5ct.conf
      # and qt6ct/qt6ct.conf on every shell start (SettingsData.updateQtIconTheme)
      # and whenever it applies its Qt colors (scripts/qt.sh), each write a
      # `sed -i` that replaces home-manager's read-only symlink with a plain file.
      # So no `qt.qt5ctSettings`/`qt6ctSettings` here — those are precisely the
      # two paths. Kvantum stays off rather than swap in another Qt theme engine.
      catppuccin.kvantum.enable = false;

      qt = {
        enable = true;
        # Keeps qt5ct/qt6ct installed and exports QT_QPA_PLATFORMTHEME=qt5ct,
        # the check DMS's Qt script runs before touching either file.
        platformTheme.name = "qtct";
      };
    })
  ];
}
