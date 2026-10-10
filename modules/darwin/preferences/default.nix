# The CustomUserPreferences entries below come from https://macos-defaults.com/
# (the `defaults` commands) and https://github.com/rgcr/m-cli (the rest).
{ lib, ... }:
let
  inherit (import ../../shared/lib.nix { inherit lib; }) importDir;
in
{
  imports = importDir { dir = ./.; };

  # Apply preference changes to the active user and refresh the Dock after a
  # rebuild. Some macOS applications still require a restart or login cycle.
  system.activationScripts.postActivation.text = ''
    killall Dock
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  '';
}
