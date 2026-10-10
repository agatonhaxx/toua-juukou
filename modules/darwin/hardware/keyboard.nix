{
  # Little of this is useful on macOS: the global option→alt remap worth having
  # is not supported yet.
  system = {
    keyboard = {
      enableKeyMapping = true;

      # Caps lock cannot remap to control and escape at once.
      remapCapsLockToControl = false;
      remapCapsLockToEscape = true;

      # Off because swapping them only causes problems.
      swapLeftCommandAndLeftAlt = false;
    };

    defaults.NSGlobalDomain = {
      "com.apple.keyboard.fnState" = true; # F1, F2, … are standard function keys
      AppleKeyboardUIMode = 2; # keyboard access to controls in dialogs

      ApplePressAndHoldEnabled = false; # no accent menu on hold, so keys repeat

      # 15 is 225 ms and 3 is 30 ms; the macOS minimums are 15 and 2.
      InitialKeyRepeat = 15;
      KeyRepeat = 3;
    };
  };
}
