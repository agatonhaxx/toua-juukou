{
  config,
  lib,
  osConfig,
  ...
}:
{
  # Identity is personal, not per-program: `modules/programs/cli/git.nix` only
  # installs git for every user, this module says who commits.
  programs.git = lib.mkIf config.programs.git.enable {
    userName = "eek";
    userEmail = "glenn@huxe.eu";

    # Work repositories live in one directory, so the identity follows the path
    # rather than the machine. Neither the identity nor the directory is written
    # here: the host holding the work repositories renders both from
    # `secrets/eek.yaml`, and the rendered file carries the `gitdir:` condition
    # itself, so this include stays unconditional and inert elsewhere. Hosts
    # without the template simply do not get the include. Signing keys belong
    # here too, one per identity, once they exist.
    includes = lib.optional (osConfig.sops.templates ? "work-git-include") {
      path = osConfig.sops.templates."work-git-include".path;
    };
  };
}
