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
