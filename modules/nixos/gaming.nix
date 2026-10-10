{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.toua.programs;
in
{
  # The Linux half of the `gaming` group. Steam, GameMode and gamescope are
  # system options — Steam especially, since its module is what brings the 32-bit
  # graphics stack, the udev rules and the firewall blocks — so they are set here
  # rather than in `modules/programs/`, which is Home Manager. The user-side
  # piece is `modules/programs/gui/mangohud.nix`.
  config = lib.mkMerge [
    (lib.mkIf cfg.steam.enable {
      programs.steam = {
        enable = true;

        # Proton-GE next to Valve's own Proton, picked per game in Steam's
        # compatibility settings.
        extraCompatPackages = [ pkgs.proton-ge-bin ];

        # These have to exist inside Steam's FHS runtime, which the user's own
        # packages do not reach.
        extraPackages = [
          pkgs.gamemode
          pkgs.mangohud
        ];

        # `protontricks.enable` is left off: `pkgs.protontricks` 1.14.1 failed its
        # own pytest suite on nixpkgs 39ad350 — two `TestFindLibraryPaths` cases
        # over a case-insensitive glob — which failed the whole build. Worth
        # retrying on a later rev; the tests are upstream's, not ours to skip.

        # Steam Link, for the machines that stream from this one.
        remotePlay.openFirewall = true;

        # Registers a gamescope session with GDM; Steam's module turns
        # `programs.gamescope` on for it by itself.
        gamescopeSession.enable = true;
      };

      # The group's machine-level pieces. They are not programs with a toggle of
      # their own, and `steam` is what the group is really about: a host that
      # takes only gamescope or MangoHud — the laptop, which wants neither the
      # scheduler nor the binfmt handler below — is not a gaming host.

      # Proton and several engines map far past the 65530 default; this is the
      # value SteamOS ships.
      boot.kernel.sysctl."vm.max_map_count" = 2147483642;

      # AppImages run directly instead of through `appimage-run` by hand.
      programs.appimage = {
        enable = true;
        binfmt = true;
      };

      # sched-ext: a scheduler that keeps the desktop responsive while a game
      # hogs the machine. The module asserts kernel >= 6.12, which this host's
      # default 6.18 already satisfies.
      services.scx = {
        enable = true;
        scheduler = "scx_bpfland";
      };
    })

    (lib.mkIf cfg.gamescope.enable {
      programs.gamescope = {
        enable = true;

        # The wrapper carries cap_sys_nice, which gamescope needs to renice
        # itself. Only this wrapped copy is on PATH now, which is why the bare
        # package was dropped from user/eek/programs/gui/niri.nix — the user
        # profile comes first and would have shadowed the capability.
        capSysNice = true;

        # `enableWsi` stays off, its default: turning it on adds
        # `pkgs.pkgsi686Linux.gamescope-wsi` to `hardware.graphics.extraPackages32`,
        # and that 32-bit output is not on cache.nixos.org, so each build would
        # need an i686 builder on this host. The session uses `pkgs.gamescope`
        # either way; what is lost is the Vulkan WSI layer for games that present
        # their own swapchain through gamescope.
      };
    })

    (lib.mkIf cfg.gamemode.enable {
      programs.gamemode.enable = true;
    })
  ];
}
