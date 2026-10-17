{ config, lib, ... }:
{
  programs.eza = lib.mkIf config.programs.eza.enable {
    # Interferes with default ls command.
    enableNushellIntegration = false;

    icons = "auto";

    # Extra options land on the `eza` alias itself, so anything here is also in
    # `ls`/`ll` — keep it to things that do not hide columns.
    extraOptions = [
      "--ignore-glob"
      ".git"
    ];
  };
}
