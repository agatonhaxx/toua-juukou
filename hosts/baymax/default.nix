{ lib, pkgs, ... }:
let
  groups = import ../../modules/groups.nix;
  inherit (import ../../modules/shared/lib.nix { inherit lib; }) mkDefaults;

  # Windows for the wheel filter below, measured from evtest captures of this
  # mouse: chatter lands within a few ms of the tick it belongs to, while a
  # genuine change of direction never came closer than 120ms. 50 splits the
  # two with room to spare. The fastest repeat of the *same* direction was 2ms
  # (one detent reported twice) against 18ms for the next real notch, so 8
  # separates those.
  reverseWindow = 50;
  repeatWindow = 8;
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

  # This host's wheel reports one detent more than once — a worn encoder, not a
  # driver problem. `mouse-wheel-debounce` (pkgs/) drops those reports by their
  # kernel timestamps, and interception-tools is what puts it *below* libinput,
  # so the events it discards are events no compositor ever sees: `intercept`
  # grabs the device, the filter rewrites the stream, and `uinput` replays it as
  # a virtual device in its place.
  #
  # It stays in this file because it is one failing wheel, not a fleet policy,
  # and because a grabbed device is one nothing else can read. The udevmon job
  # is scoped to that wheel by name, and to the relative-event codes only a
  # wheel reports, so nothing else is ever grabbed — the mouse also presents
  # two keyboard interfaces under the same name.
  services.interception-tools = {
    enable = true;

    # Contributes the filter to udevmon's PATH, which is where the job finds it
    # by name.
    plugins = [ pkgs.mouse-wheel-debounce ];

    udevmonConfig = ''
      - JOB: "intercept -g $DEVNODE | mouse-wheel-debounce --reverse-window ${toString reverseWindow} --repeat-window ${toString repeatWindow} | uinput -d $DEVNODE"
        DEVICE:
          NAME: "Mionix Co. Naos 3200 Mouse"
          EVENTS:
            EV_REL: [REL_WHEEL, REL_WHEEL_HI_RES]
    '';
  };

  services.openssh = {
    enable = true;
    openFirewall = true;
    generateHostKeys = true;
    settings.PermitRootLogin = "prohibit-password";
  };
}
