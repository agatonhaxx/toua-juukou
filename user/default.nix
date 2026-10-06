{
  pkgs,
  config,
  lib,
  self,
  self',
  inputs,
  inputs',
  ...
}:
let
  inherit (import ../modules/shared/lib.nix { inherit lib; }) mkManagedUsers;
  cfg = config.toua;
  users = mkManagedUsers cfg;
in
{
  config = {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;

      extraSpecialArgs = {
        inherit
          self
          self'
          inputs
          inputs'
          ;
      };

      sharedModules = [
        { home.stateVersion = "26.05"; }
      ];

      users = lib.mapAttrs (_: user: user.homeModule) users;
    };

    users.users = lib.mapAttrs' (
      user: _:
      lib.nameValuePair user {
        home = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/${user}" else "/home/${user}";
        shell = pkgs.fish;
      }
    ) users;
  };
}
