{ config, lib, ... }:
{
  programs.eza = lib.mkIf config.programs.eza.enable {
    # Interferes with default ls command.
    enableNushellIntegration = false;

    icons = "auto";

    extraOptions = [
      "--no-permissions"
      "--no-user"
      "--ignore-glob"
      ".git"
    ];
  };
}
