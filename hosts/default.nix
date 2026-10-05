{
  lib,
  self,
  inputs,
  ...
}:
let
  additionalClasses = {
    wsl = "nixos";
    raspberry-pi = "nixos";
  };

  normaliseClass = class: additionalClasses.${class} or class;
in
{
  imports = [ inputs.easy-hosts.flakeModule ];

  easy-hosts = {
    shared.modules = [
      ../modules/shared
    ];

    inherit additionalClasses;

    perClass =
      class:
      let
        normalisedClass = normaliseClass class;
      in
      {
        modules = builtins.concatLists [
          [
            "${self}/modules/${normalisedClass}"
          ]

          (lib.optionals (normalisedClass == "nixos") [
            inputs.home-manager.nixosModules.home-manager
            inputs.sops-nix.nixosModules.sops
            # Imported for every NixOS host, but inert unless a host declares
            # `disko.devices` — only wall-e does.
            inputs.disko.nixosModules.disko
          ])

          (lib.optionals (class == "darwin") [
            inputs.home-manager.darwinModules.home-manager
            inputs.darwin-custom-icons.darwinModules.default
            inputs.darwin-login-items.darwinModules.default
            inputs.nix-homebrew.darwinModules.nix-homebrew
            inputs.sops-nix.darwinModules.sops
          ])

          (lib.optionals (class == "wsl") [
            inputs.nixos-wsl.nixosModules.default
          ])
        ];
      };

    hosts = {
      # keep-sorted start block=yes newline_separated=yes
      baymax = {
        arch = "x86_64";
        class = "nixos";
      };

      bender = {
        arch = "x86_64";
        class = "nixos";
      };

      # TODO correct hostname?
      mac = {
        arch = "aarch64";
        class = "darwin";
      };

      ponkotsu = {
        arch = "x86_64";
        class = "wsl";
      };

      # Hetzner Cloud VPS, provisioned from scratch with `nixos-anywhere`.
      wall-e = {
        arch = "x86_64";
        class = "nixos";
      };

      # TODO add rpi
      # zuko = {
      #   arch = "aarch64";
      #   class = "raspberry-pi";
      # };
      # keep-sorted end
    };
  };
}
