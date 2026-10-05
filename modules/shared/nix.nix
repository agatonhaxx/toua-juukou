{
  pkgs,
  inputs,
  config,
  ...
}:
{
  nix = {
    registry = {
      n.flake = inputs.nixpkgs;
    };

    package = pkgs.lixPackageSets.stable.lix;

    nixPath = [ "nixpkgs=${inputs.nixpkgs.outPath}" ];

    gc = {
      automatic = true;
      options = "--delete-older-than 3d";
    }
    // (
      if pkgs.stdenv.hostPlatform.isDarwin then
        {
          interval = {
            Hour = 3;
            Minute = 15;
          };
        }
      else
        {
          dates = "*-*-* 03:15";
        }
    );

    settings = {
      experimental-features = [
        # keep-sorted start
        "flakes"
        "nix-command"
        # keep-sorted end
      ];
      auto-optimise-store = !pkgs.stdenv.hostPlatform.isDarwin;
      warn-dirty = false;
      extra-platforms = [
        # keep-sorted start
        "aarch64-darwin"
        "x86_64-darwin"
        # keep-sorted end
      ];

      build-users-group = "nixbld";
      trusted-users = [
        # keep-sorted start
        "root"
        config.toua.primaryUser
        # keep-sorted end
      ];
      sandbox = false;
      use-xdg-base-directories = true;
      substituters = [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
        "https://nixpkgs-unfree.cachix.org"
        "https://catppuccin.cachix.org"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
        "catppuccin.cachix.org-1:noG/4HkbhJb+lUAdKrph6LaozJvAeEEZj4N732IysmU="
      ];
    };
  };

  nixpkgs = {
    overlays = [
    ];

    config = {
      allowUnfree = true;
      # showDerivationWarnings = ["maintainerless"];
    };
  };
}
