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
    settings.user = {
      name = "Glenn Dahl";
      email = "glenn.dahl@svenskaspel.se";
    };

    # Work repositories live in one directory, so the identity follows the path
    # rather than the machine. Neither the identity nor the directory is written
    # here: the host holding the work repositories renders both from
    # `secrets/eek.yaml`, and the rendered file carries the `gitdir:` condition
    # itself, so this include stays unconditional and inert elsewhere. Hosts
    # without the template simply do not get the include. Signing keys belong
    # here too, one per identity, once they exist.
    includes = [
      {
        condition = "gitdir:~/dev/eek/";
        contents = {
          user = {
            name = "eek";
            email = "glenn@huxe.eu";
          };
          core.sshCommand = "ssh -i ~/.ssh/id_ed25519_eek -o IdentitiesOnly=yes";
        };
      }
      {
        condition = "gitdir:~/dev/svs/";
        contents.core.sshCommand = "ssh -i ~/.ssh/id_ed25519_work -o IdentitiesOnly=yes";
      }
    ];
  };
}
