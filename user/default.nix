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
  cfg = config.toua;
  primaryUser = cfg.users.${cfg.primaryUser} or { };
  users = cfg.users // {
    ${cfg.primaryUser} = primaryUser // {
      enable = true;
      homeModule = primaryUser.homeModule or ./home.nix;
    };
  };
  enabledUsers = lib.filterAttrs (_: user: user.enable or false) users;
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

      users = lib.mapAttrs (_: user: user.homeModule) enabledUsers;
    };

    users.users = lib.mkIf cfg.manageUser (
      lib.mapAttrs' (
        user: _:
        lib.nameValuePair user {
          home = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/${user}" else "/home/${user}";
          shell = pkgs.fish;
        }
      ) enabledUsers
    );
  };
}
