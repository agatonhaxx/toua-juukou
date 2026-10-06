{
  config,
  lib,
  ...
}:
let
  enabled = config.programs.neovim.enable || (config.programs.nvim-eek.enable or false);
  mimeTypes = [
    "application/json"
    "text/english"
    "text/plain"
    "text/x-makefile"
    "text/x-c++hdr"
    "text/x-c++src"
    "text/x-chdr"
    "text/x-csrc"
    "text/x-java"
    "text/x-moc"
    "text/x-pascal"
    "text/x-tcl"
    "text/x-tex"
    "application/x-shellscript"
    "text/x-c"
    "text/x-c++"
  ];
  associations = lib.genAttrs mimeTypes (_: "nvim.desktop");
in
{
  programs.neovim.enable = lib.mkDefault config.toua.programs.neovim.enable;

  xdg.mimeApps = lib.mkIf enabled {
    enable = true;
    associations.added = associations;
    defaultApplications = associations;
  };

  xdg.desktopEntries.nvim = lib.mkIf enabled {
    name = "Neovim";
    genericName = "Text Editor";
    comment = "Edit text files";
    exec = "nvim %F";
    terminal = true;
    categories = [
      "Utility"
      "TextEditor"
    ];
    mimeType = mimeTypes;
  };
}
