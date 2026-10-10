{ config, lib, ... }:
let
  # Every service declares its port through `mkServiceOption`, and its default of
  # 0 means the service binds none of its own — that is how the ones that only
  # ever sit behind nginx, and borg, are declared.
  #
  # Two enabled services on one host cannot hold the same port, and nothing else
  # would say so: the second one simply fails to bind at start. baymax already
  # carries a port moved by hand for this reason (`sabnzbd.nix`), so the check
  # is here rather than in a comment.
  #
  # The scope is the host, since that is the scope a port lives in. Ports nginx
  # opens itself, and anything a service picks up from a module of its own rather
  # than from `toua.services`, are outside it.
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
