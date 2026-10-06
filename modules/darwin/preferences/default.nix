# All the configuration options are documented here: https://daiderd.com/nix-darwin/manual/index.html#sec-options
# Incomplete list of macOS `defaults` commands: https://macos-defaults.com/
#
# This pertains to anything prefixed with CustomUserPreferences
# Customize settings that not supported by nix-darwin directly
# see the source code of this project to get more undocumented options:
#    https://github.com/rgcr/m-cli
#
# All custom entries can be found by running `defaults read` command.
# or `defaults read xxx` to read a specific domain.
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
