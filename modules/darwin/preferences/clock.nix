{
  system.defaults = {
    NSGlobalDomain.AppleICUForce24HourTime = true;

    menuExtraClock = {
      # Use a 24-hour digital clock and show the date.
      Show24Hour = true;

      # show digital clock
      IsAnalog = false;

      ShowAMPM = false;

      # Show date can imply the result of ShowDayOfMonth, ShowDayOfWeek, and ShowSeconds.
      # 0 = show the date; 1 and 2 hide it.
      ShowDate = 0;

      # show day of month
      # ShowDayOfMonth = false;

      # show day of week
      # ShowDayOfWeek = false;

      # show seconds
      # ShowSeconds = false;
    };
  };
}
