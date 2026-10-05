{
  system.defaults.NSGlobalDomain = {
    AppleInterfaceStyle = "Dark";
    AppleInterfaceStyleSwitchesAutomatically = false;
  };

  system.defaults.CustomUserPreferences.NSGlobalDomain = {
    # macOS exposes a fixed accent palette rather than arbitrary system theme
    # colors. Purple is the closest native accent to Catppuccin Mocha's mauve;
    # the selection color can use the exact palette RGB values.
    AppleAccentColor = 5;
    AppleHighlightColor = "0.796078 0.650980 0.968627 Mauve";
  };
}
