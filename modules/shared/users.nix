{
  config,
  lib,
  ...
}:
let
  # One public key per line in sshd's format; trimmed because a stray carriage
  # return would otherwise yield a key sshd silently rejects.
  keys = lib.filter (line: line != "" && !(lib.hasPrefix "#" line)) (
    map lib.trim (lib.splitString "\n" (builtins.readFile ../../keys/authorized_keys))
  );
in
{
  users.users.${config.toua.primaryUser}.openssh.authorizedKeys.keys = keys;
}
