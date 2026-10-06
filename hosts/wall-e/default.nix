{
  imports = [
    ../../user

    ./disko.nix
  ];

  toua = {
    # wall-e is a headless service host. Keep the shared terminal setup, but do
    # not pull graphical applications or media players into its closure.
    profiles.headless.enable = true;
    primaryUser = "eek";
    users.eek.homeModule = ../../user/eek;

    domain = "huxe.eu";
    email = "glenn@huxe.eu";
  };

  # These NixOS options default to true even without a desktop. They install
  # MIME, icon, sound-theme and fontconfig data that wall-e does not use.
  fonts.fontconfig.enable = false;
  xdg = {
    icons.enable = false;
    mime.enable = false;
    sounds.enable = false;
  };

  # Set as a default rather than on kanidm's certificate because it is a fact
  # about this host's resolver, and it applies to every certificate issued here.
  #
  # lego's propagation check asks the box's own resolver — here the
  # systemd-resolved stub at 127.0.0.53 — which never returns the challenge TXT
  # record even though Cloudflare publishes it straight away, so every order
  # died on "time limit exceeded". Cloudflare's authoritative nameservers do
  # answer, so only the recursive half of the check is dropped.
  security.acme.defaults.extraLegoFlags = [ "--dns.propagation.disable-rns" ];

  # Static, mirroring the shape the dotfiles repo gives its Hetzner host. Hetzner
  # hands the public address out as a /32 routed through a link-local gateway, so
  # the address and the route to that gateway are both spelled out. `interface` is
  # not optional on either gateway when `useNetworkd` is on — nixpkgs asserts it.
  networking = {
    hostName = "wall-e";

    # One NIC, so `net.ifnames=0` names it eth0, which is what the stock image
    # calls it and what the addresses below are bound to. That also makes the MAC
    # udev rule dotfiles carries unnecessary here.
    usePredictableInterfaceNames = false;
    useNetworkd = true;

    defaultGateway = {
      address = "172.31.1.1";
      interface = "eth0";
    };

    defaultGateway6 = {
      address = "fe80::1";
      interface = "eth0";
    };

    # Hetzner's own resolvers, which is what the box already resolves through.
    nameservers = [
      "185.12.64.1"
      "185.12.64.2"
    ];

    interfaces.eth0 = {
      ipv4 = {
        addresses = [
          {
            address = "2.29.60.81";
            prefixLength = 32;
          }
        ];

        routes = [
          {
            address = "172.31.1.1";
            prefixLength = 32;
          }
        ];
      };

      ipv6 = {
        addresses = [
          {
            address = "2a01:4f9:c014:a051::1";
            prefixLength = 64;
          }
        ];

        routes = [
          {
            address = "fe80::1";
            prefixLength = 128;
          }
        ];
      };
    };
  };

  # A rebuild that edits any of the above would otherwise restart networkd
  # underneath the SSH session running that rebuild.
  systemd.services.systemd-networkd.stopIfChanged = false;

  # UEFI only, and the firmware reaches the bootloader through the removable
  # fallback path rather than an NVRAM entry — see ./disko.nix, which mounts the
  # ESP at `/boot` for systemd-boot's sake.
  boot.loader = {
    systemd-boot = {
      enable = true;

      # systemd-boot cannot read the kernel out of `/nix/store`, so /boot carries
      # a kernel and initrd per generation — call it ~100M each. Ten of them fits
      # the 2G ESP with room to spare; leaving this null would fill the partition
      # and the next rebuild would fail.
      configurationLimit = 10;
    };

    # Spelled out because the default has moved between nixpkgs releases and this
    # one has to agree with the mountpoint in ./disko.nix.
    efi.efiSysMountPoint = "/boot";
  };

  # The disk is virtio-scsi — `/dev/sda`, `scsi-0QEMU_QEMU_HARDDISK`, sitting on
  # virtio5 — and neither the transport nor the HBA driver is in the nixpkgs
  # default initrd set, which is desktop-flavoured (hid_*, atkbd, i8042) and
  # assumes AHCI or NVMe. Without these, stage-1 cannot mount the root filesystem
  # and the box drops to an emergency shell with no way in.
  boot.initrd = {
    availableKernelModules = [
      # keep-sorted start
      "virtio_blk"
      "virtio_net"
      "virtio_pci"
      "virtio_scsi"
      # keep-sorted end
    ];

    kernelModules = [
      # keep-sorted start
      "virtio_balloon"
      "virtio_console"
      "virtio_rng"
      # keep-sorted end
    ];
  };

  # `panic=1` reboots instead of hanging: `panic=0`, the default, waits for
  # somebody to press a key, and on this box there is nobody to press it.
  #
  # The rest of this is verbatim from the stock image's own command line, which
  # is known good on this instance: `console=tty1` is what puts a login prompt
  # on the console Hetzner shows, and `console=ttyS0` last is what makes
  # systemd's getty generator start `serial-getty@ttyS0` — nothing else here
  # would pass it, so an install would quietly drop that second prompt.
  # `consoleblank=0` stops the screen going dark. The stock line carries no baud
  # rate and this does not add one: guessing would reconfigure a port whose
  # working rate cannot be checked from here.
  boot.kernelParams = [
    "consoleblank=0"
    "systemd.show_status=true"
    "console=tty1"
    "console=ttyS0"
    "panic=1"
  ];

  # Both are modules in the kernel this host builds (`CONFIG_TCP_CONG_BBR=m`,
  # `CONFIG_NET_SCH_FQ=m`) and the sysctls below name things it cannot resolve
  # until they are loaded — the assignment fails silently without these.
  boot.kernelModules = [
    # keep-sorted start
    "sch_fq"
    "tcp_bbr"
    # keep-sorted end
  ];

  boot.kernel.sysctl = {
    # This kernel defaults to cubic (`CONFIG_DEFAULT_TCP_CONG="cubic"`); BBR
    # holds up better once a path loses packets, which is every path this box
    # serves over.
    "net.ipv4.tcp_congestion_control" = "bbr";

    # The qdisc BBR is meant to be paired with. `cake` shapes a link you own end
    # to end; this is a virtio NIC in somebody else's datacentre.
    "net.core.default_qdisc" = "fq";
  };

  # Compaction otherwise runs synchronously inside the allocation that ran out
  # of contiguous pages. `enabled` is left at the kernel default on purpose —
  # `always` inflates RSS, which is a poor trade on a small VPS.
  boot.kernel.sysfs.kernel.mm.transparent_hugepage.defrag = "defer";

  # Hetzner's out-of-band console and password reset ride on the guest agent. On
  # a box with no other way in, that is the safety net.
  services.qemuGuest.enable = true;

  # No shared module enables sshd; on a VPS it is the only way in. The host key
  # has to exist before sops can derive this host's age recipient, and
  # `../../.sops.yaml` does not list wall-e yet.
  services.openssh = {
    enable = true;
    generateHostKeys = true;

    # `modules/shared/users.nix` already installs `keys/authorized_keys`, so
    # these remove password paths rather than close anything that was open.
    # Note this also ends `root@wall-e` logins; the account is `eek`.
    #
    # No algorithm allowlists: they need keeping current as clients move, and a
    # peer that falls outside one is locked out of a box whose only other door
    # is the console.
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;

      # Drop sessions that stop answering rather than holding the slot open.
      ClientAliveInterval = 60;
      ClientAliveCountMax = 5;

      # Caps concurrent *unauthenticated* connections per source address, which
      # is the DHEat DoS. 1 was too tight: a `nixos-rebuild --target-host` from
      # a machine that also held an interactive session here was refused. The
      # client reported a key rejection rather than the dropped connection this
      # cap is supposed to cause, so the mechanism is unconfirmed — but a second
      # slot costs nothing and the cap still stops parallel guessing.
      PerSourceMaxStartups = 2;
      PerSourceNetBlockSize = "32:128";
    };
  };

  # The only port on the public internet, and nothing else here watches it.
  # `ignoreIP` stays at its default — loopback only — so a ban you inflict on
  # yourself is a console login away from being undone rather than state
  # surgery. `maxretry` is low because key authentication does not fail by
  # accident: anything that misses five times is not you.
  services.fail2ban = {
    enable = true;
    maxretry = 5;

    bantime-increment = {
      enable = true;
      multipliers = "4 8 16 32 64 128 256 512 1024";
      maxtime = "192h";
    };
  };
}
