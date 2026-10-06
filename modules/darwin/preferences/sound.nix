{
  system.defaults.NSGlobalDomain = {
    # disable beep sound when pressing volume up/down key
    "com.apple.sound.beep.feedback" = 0;

    # Mute the beep. `null` is the option's default and nix-darwin drops null
    # values before writing, so it would leave the beep at its current volume.
    "com.apple.sound.beep.volume" = 0.0;
  };
}
