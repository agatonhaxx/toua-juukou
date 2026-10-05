{
  config,
  lib,
  pkgs,
  ...
}:
let
  flowDesktopBeta = pkgs.stdenvNoCC.mkDerivation {
    pname = "flow-desktop-beta";
    version = "0.1.0-beta2";

    src = pkgs.fetchurl {
      url = "https://github.com/Flow-Tube/Flow-Desktop/releases/download/v0.1.0-beta2/Flow_0.1.0-beta2_darwin_aarch64.dmg";
      hash = "sha256-kiw16zyhNtBxU03d8n/ttY258qq50NgmXq/Ss5EcB0I=";
    };

    nativeBuildInputs = [ pkgs.undmg ];
    sourceRoot = ".";

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/Applications"
      cp -R ./*.app "$out/Applications/"

      runHook postInstall
    '';

    meta = {
      description = "Privacy-first YouTube and YouTube Music client";
      homepage = "https://github.com/Flow-Tube/Flow-Desktop";
      license = lib.licenses.gpl3Only;
      platforms = lib.platforms.darwin;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  };
in
{
  # Imported by the Darwin system modules, not by Home Manager's GUI modules.
  environment.systemPackages = lib.mkIf config.toua.programs.flow.enable [ flowDesktopBeta ];
}
