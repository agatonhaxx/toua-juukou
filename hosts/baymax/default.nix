{ lib, ... }:
let
  groups = import ../../modules/groups.nix;
  inherit (import ../../modules/shared/lib.nix { inherit lib; }) mkDefaults;
in
{
  imports = [
    ../../user
    ./disko.nix
    ./hardware-configuration.nix
  ];

  # The only `boot.loader` definition: `hardware-configuration.nix` carries the
  # hardware facts and filesystems, this carries boot policy. `/boot` is the ESP
  # declared in ./disko.nix, and the mount point is spelled out because its
  # default has moved between nixpkgs releases.
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 10;
    };
    systemd-boot.graceful = true;
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };

  networking = {
    hostName = "baymax";
    networkmanager.enable = true;

    # Flow syncs between machines over this port.
    firewall.allowedTCPPorts = [ 43251 ];
  };

  systemd.services.NetworkManager-wait-online.enable = false;

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICPdH1DIHY40eBUaRiMsneGlZsLJ+lQFIQwCAe4KTxCU"
  ];
  users.users.root.openssh.authorizedKeys.keyFiles = [ ../../keys/authorized_keys ];

  services.avahi.ipv6 = false;

  toua = lib.mkMerge [
    (mkDefaults groups.dev)
    (mkDefaults groups.agents)
    {
      profiles.desktop.enable = true;

      programs = {
        blueman.enable = true;
        bluetooth.enable = true;
      };

      primaryUser = "eek";
      users.eek.homeModule = ../../user/eek;
    }
  ];

  services.openssh = {
    enable = true;
    openFirewall = true;
    generateHostKeys = true;
    settings.PermitRootLogin = "prohibit-password";
  };
}
