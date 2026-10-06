{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  undmg,
  dpkg,
  autoPatchelfHook,
  wrapGAppsHook3,
  gtk3,
  webkitgtk_4_1,
  libsoup_3,
  dbus,
  gst_all_1,
  nodejs,
}:
let
  system = stdenvNoCC.hostPlatform.system;
  sources = {
    aarch64-darwin = {
      file = "darwin_aarch64.dmg";
      hash = "sha256-kiw16zyhNtBxU03d8n/ttY258qq50NgmXq/Ss5EcB0I=";
    };
    x86_64-darwin = {
      file = "darwin_x64.dmg";
      hash = "sha256-1IWu46HS3HzB7ScVzly/EYWuzsd+RpAUfdeVdQExd+Q=";
    };
    aarch64-linux = {
      file = "linux_arm64.deb";
      hash = "sha256-2fIooG6GRJ1vTaABXn07NnisuG000szNnGHfarMwDpw=";
    };
    x86_64-linux = {
      file = "linux_amd64.deb";
      hash = "sha256-5i+b4bg/B3xFhcd5si6ojXBFVYq+BEginRtfqyAlmfc=";
    };
  };
  source = sources.${system} or (throw "Flow is not packaged for ${system}");
in
stdenvNoCC.mkDerivation (
  finalAttrs:
  {
    pname = "flow-desktop-beta";
    version = "0.1.0-beta2";

    src = fetchurl {
      url = "https://github.com/Flow-Tube/Flow-Desktop/releases/download/v${finalAttrs.version}/Flow_${finalAttrs.version}_${source.file}";
      hash = source.hash;
    };

    strictDeps = true;
    sourceRoot = ".";
    dontBuild = true;

    nativeBuildInputs =
      lib.optionals stdenvNoCC.hostPlatform.isDarwin [ undmg ]
      ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [
        dpkg
        autoPatchelfHook
        wrapGAppsHook3
      ];

    buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [
      stdenv.cc.cc.lib
      gtk3
      webkitgtk_4_1
      libsoup_3
      dbus
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-plugins-ugly
      gst_all_1.gst-libav
    ];

    installPhase = ''
      runHook preInstall
    ''
    + lib.optionalString stdenvNoCC.hostPlatform.isDarwin ''
      mkdir -p "$out/Applications"
      cp -R ./*.app "$out/Applications/"
    ''
    + lib.optionalString stdenvNoCC.hostPlatform.isLinux ''
      mkdir -p "$out"
      cp -R usr/. "$out/"
      substituteInPlace "$out/share/applications/Flow Beta.desktop" \
        --replace-fail "Exec=flow" "Exec=$out/bin/flow %U"
    ''
    + ''
      runHook postInstall
    '';

    preFixup = lib.optionalString stdenvNoCC.hostPlatform.isLinux ''
      gappsWrapperArgs+=(
        --set-default FLOW_NODE "${lib.getExe nodejs}"
        --set-default FLOW_INTEGRITY_SCRIPT "$out/lib/Flow Beta/sidecar/integrity.cjs"
      )
    '';

    meta = {
      description = "Privacy-first YouTube and YouTube Music client";
      homepage = "https://github.com/Flow-Tube/Flow-Desktop";
      license = lib.licenses.gpl3Only;
      platforms = builtins.attrNames sources;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    }
    // lib.optionalAttrs stdenvNoCC.hostPlatform.isLinux {
      mainProgram = "flow";
    };
  }
  // lib.optionalAttrs stdenvNoCC.hostPlatform.isLinux {
    unpackPhase = ''
      runHook preUnpack
      dpkg-deb -x "$src" .
      runHook postUnpack
    '';
  }
)
