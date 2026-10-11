{ config, lib, ... }:
{
  # The system half of `toua.programs.chromium`: Linux Chromium reads policies
  # from /etc/chromium, and Home Manager has no policies option. Nothing is
  # installed here — only the policy files are written; the browser is the
  # user's package in user/eek/programs/gui/chromium.nix.
  programs.chromium = lib.mkIf config.toua.programs.chromium.enable {
    enable = true;

    # Managed policies, so they are not offered to the user to change: no
    # translate prompt, and no offer to save or check passwords.
    extraOpts = {
      PasswordLeakDetectionEnabled = false;
      PasswordManagerEnabled = false;
      TranslateEnabled = false;
    };
  };
}
