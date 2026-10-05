{ config, lib, ... }:
let
  cfg = config.toua.mac.homebrew;
in
{
  environment = lib.mkIf cfg.enable {
    variables = {
      # Do not send analytic data to Homebrew
      HOMEBREW_NO_ANALYTICS = "1";

      # don't allow insecure redirects
      HOMEBREW_NO_INSECURE_REDIRECT = "1";

      # don't show emoji in the output
      HOMEBREW_NO_EMOJI = "1";

      # I don't need any hints because nix handles homebrew for me
      HOMEBREW_NO_ENV_HINTS = "1";
    };

    # Add Homebrew to PATH so formulae can be executed normally.
    systemPath = [ "${config.homebrew.prefix}/bin" ];
  };
}
