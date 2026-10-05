{
  config,
  lib,
  self,
  ...
}:
let
  inherit (import ../shared/lib.nix { inherit lib self; }) mkSecret;
  managedUsers = lib.filterAttrs (_: user: user.enable or false) config.toua.users;
  users = managedUsers // {
    ${config.toua.primaryUser} = managedUsers.${config.toua.primaryUser} or { };
  };
in
{
  # `neededForUsers` decrypts before accounts are created, so these secrets stay
  # root-owned and each user's hash is read from secrets/<username>.yaml.
  sops.secrets = lib.mapAttrs' (username: _: {
    name = username;
    value = mkSecret {
      file = username;
      dir = "";
      key = "password";
      neededForUsers = true;
    };
  }) users;

  users.users =
    lib.recursiveUpdate
      (lib.mapAttrs (username: _: {
        isNormalUser = true;
        group = "users";
        hashedPasswordFile = config.sops.secrets.${username}.path;
      }) users)
      {
        ${config.toua.primaryUser}.extraGroups = [ "wheel" ];
        root.hashedPasswordFile = config.sops.secrets.${config.toua.primaryUser}.path;
      };
}
