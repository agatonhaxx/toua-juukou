{
  lib,
  config,
  inputs,
  osConfig,
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

    (mkIf osConfig.toua.programs.gui.enable {
      # Papirus icon theme for graphical applications.
      catppuccin.gtk.icon.enable = true;
      catppuccin.firefox.enable = false;
    })

    # qt5ct is not available on Darwin. The app gate also keeps Qt and its
    # configuration tools out of headless Linux hosts.
    (mkIf (pkgs.stdenv.hostPlatform.isLinux && osConfig.toua.programs.gui.enable) {
      catppuccin = {
        # Qt apps need the Home Manager Qt module with qtct as platform theme.
        # Kvantum is opted out because it conflicts with qt5ct (it requires
        # `qt.style.name = "kvantum"`).
        qt5ct.enable = true;
        kvantum.enable = false;
      };

      qt = {
        enable = true;
        platformTheme.name = "qtct";
      };
    })
  ];
}
