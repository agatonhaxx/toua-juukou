# Chromium extensions, installed from pinned CRX files.
#
# The Web Store has no immutable URL: the update endpoint answers with whatever
# version suits the `prodversion` below, so the hash is what pins the bytes. A
# hash mismatch means the store moved on — bump `version` and `hash` together,
# with the version read from inside the new CRX
# (`ouch decompress --format zip <crx>`, then manifest.json). Chromium refuses a
# CRX whose own version differs from `external_version`, which is what this
# `version` becomes.
{ fetchurl }:
let
  mkExtension =
    {
      id,
      version,
      hash,
    }:
    {
      inherit id version;

      crx = fetchurl {
        name = "${id}-${version}.crx";
        url = "https://clients2.google.com/service/update2/crx?response=redirect&os=linux&arch=x86_64&os_arch=x86_64&nacl_arch=x86-64&prod=chromiumcrx&prodchannel=unknown&prodversion=154.0.8037.97&acceptformat=crx3&x=id%3D${id}%26installsource%3Dondemand%26uc";
        inherit hash;
      };
    };
in
{
  # Vault, passkeys and password sharing; the passwords it holds are the reason
  # Chromium's own manager is off in modules/nixos/chromium.nix.
  bitwarden = mkExtension {
    id = "nngceckbapebfimnlniiiahkandclblb";
    version = "2026.9.3";
    hash = "sha256-mWT2YKEQI8sZpzC3+Qg1PsHa53oCfIGSMV0Kfz2O+SE=";
  };

  # Fills in cookie and consent dialogs from the user's own preference set
  # instead of hiding them.
  consent-o-matic = mkExtension {
    id = "mdjildafknihdffpkfmmpnpoiajfjnjd";
    version = "1.1.3";
    hash = "sha256-qdMdkakBMffTyrLcPjN+Q/dfTyto5/3oEuDNJKgTvpg=";
  };

  # Persistent tab names, per site or per page.
  easy-rename-tab = mkExtension {
    id = "pibhnjoadcblbjijfdjeblbbcgpjgbbh";
    version = "1.2";
    hash = "sha256-5Xl/q/0FGinM9f344XGqGt3KJu8IEVqJsc7o74ocxUs=";
  };

  # Web page to Markdown file. The original MarkDownload is MV2 and no longer
  # served by the store, so this is the continuation of it.
  markdownload = mkExtension {
    id = "lfihmpgmbpingelkgmodjgghdcjeiikk";
    version = "4.0.0.1";
    hash = "sha256-74oEKi9+vaGzJ7eXRrwENOpVryDZZJNT44vKxuATfrg=";
  };
}
