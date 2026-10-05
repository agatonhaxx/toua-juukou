{
  system.defaults.CustomUserPreferences = {
    # Free Command-Space from Spotlight so Raycast can own it.
    "com.apple.symbolichotkeys".AppleSymbolicHotKeys."64" = {
      enabled = false;
      value = {
        parameters = [
          65535
          49
          1048576
        ];
        type = "standard";
      };
    };

    "com.raycast.macos".raycastGlobalHotkey = "Command-49";
  };
}
