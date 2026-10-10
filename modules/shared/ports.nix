{ config, lib, ... }:
let
  # Two enabled services cannot claim one port — the second just fails to bind.
  # A service declared with port 0 binds none, so it is outside the check.
  enabled = lib.filterAttrs (_: service: service.enable or false) config.toua.services;

  byPort = lib.groupBy (name: toString (enabled.${name}.port or 0)) (lib.attrNames enabled);

  collisions = lib.filter (names: lib.length names > 1) (
    builtins.attrValues (removeAttrs byPort [ "0" ])
  );
in
{
  assertions = [
    {
      assertion = collisions == [ ];
      message = "toua.services: two enabled services claim the same port: ${
        lib.concatMapStringsSep ", " (names: lib.concatStringsSep " and " names) collisions
      }";
    }
  ];
}
