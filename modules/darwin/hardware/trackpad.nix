{
  system.defaults = {
    # disable natural scrolling
    NSGlobalDomain."com.apple.swipescrolldirection" = false;

    # disable Force Click lookup
    NSGlobalDomain."com.apple.trackpad.forceClick" = false;

    trackpad = {
      ForceSuppressed = true;

      # enable tap to click
      Clicking = true;

      # enable two finger right click
      TrackpadRightClick = true;

      # disable three finger drag so I can swap workspaces with 3 fingers
      TrackpadThreeFingerDrag = false;
    };
  };
}
