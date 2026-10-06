{
  config,
  lib,
  ...
}:
let
  associations = lib.genAttrs [
    "video/*"
    "audio/*"
    "image/*"
  ] (_: "mpv.desktop");
in
{
  programs.mpv.enable = lib.mkDefault config.toua.programs.mpv.enable;

  xdg.mimeApps = lib.mkIf config.programs.mpv.enable {
    enable = true;
    associations.added = associations;
    defaultApplications = associations;
  };
}
