{
  config,
  lib,
  ...
}:
let
  # `../../keys/authorized_keys` is one public key per line in sshd's own
  # format. Trimmed before filtering so a stray carriage return cannot silently
  # yield a key that sshd rejects.
  keys = lib.filter (line: line != "" && !(lib.hasPrefix "#" line)) (
    map lib.trim (lib.splitString "\n" (builtins.readFile ../../keys/authorized_keys))
  );
in
{
  users.users.${config.toua.primaryUser}.openssh.authorizedKeys.keys = keys;
}
