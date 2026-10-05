{
  lib,
  config,
  ...
}:
{
  programs.firefox = lib.mkIf config.programs.firefox.enable {
    # Enterprise policies (see: about:policies)
    policies = {
      # Privacy
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableFirefoxAccounts = false;

      # DNS over HTTPS
      DNSOverHTTPS = {
        Enabled = true;
        ProviderURL = "https://mozilla.cloudflare-dns.com/dns-query";
        Fallback = false;
      };

      # Extensions installed via policy. `force_installed` cannot be removed;
      # `normal_installed` can be removed but is re-installed on next start.
      # Both auto-update from addons.mozilla.org, so no hashes to maintain.
      ExtensionSettings = {
        # uBlock Origin — force-installed, auto-updated by Mozilla
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
          default_area = "menupanel";
        };

        # Unlock (paywalls)
        "{9a0be525-4e0d-4954-8b9e-1ef2218d851d}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/unlock/latest.xpi";
          installation_mode = "normal_installed";
        };

        # MarkDownload
        "{1c5e4c6f-5530-49a3-b216-31ce7d744db0}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/markdownload/latest.xpi";
          installation_mode = "normal_installed";
        };

        # Vimium
        "{d7742d87-e61d-4b78-b8a1-b469842139fa}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/vimium-ff/latest.xpi";
          installation_mode = "normal_installed";
        };

        # React Developer Tools
        "@react-devtools" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/react-devtools/latest.xpi";
          installation_mode = "normal_installed";
        };

        # Duplicate Tabs Closer
        "jid0-RvYT2rGWfM8q5yWxIxAHYAeo5Qg@jetpack" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/duplicate-tabs-closer/latest.xpi";
          installation_mode = "normal_installed";
        };

        # Bitwarden
        "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
          installation_mode = "normal_installed";
        };

        # qui (qBittorrent integration)
        "qui@s0up4200" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/qui/latest.xpi";
          installation_mode = "normal_installed";
        };

        # Consent-O-Matic
        "gdpr@cavi.au.dk" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/consent-o-matic/latest.xpi";
          installation_mode = "normal_installed";
        };
      };
    };

    profiles = {
      default = {
        id = 0;
        name = "default";
        isDefault = true;
        extensions.force = true;

        settings = {
          # --- Privacy ---
          "browser.send_pings" = false;
          "browser.urlbar.suggest.quicksuggest.sponsored" = false;
          "dom.security.https_only_mode" = true;
          "privacy.donottrackheader.enabled" = true;
          "privacy.trackingprotection.enabled" = true;
          "privacy.trackingprotection.socialtracking.enabled" = true;
          "privacy.userContext.enabled" = false; # containers off

          # --- Passwords & form data ---
          "signon.rememberSignons" = false;
          "browser.formfill.enable" = false;
          "extensions.formautofill.creditCards.enabled" = false;
          "privacy.clearOnShutdown_v2.formdata" = true;

          # --- Network ---
          "network.dns.disablePrefetch" = true;
          "network.prefetch-next" = false;
          "network.http.speculative-parallel-limit" = 0;

          # --- UI ---
          "browser.startup.homepage" = "about:home";
          "browser.startup.page" = 3; # restore previous session
          "browser.download.useDownloadDir" = false; # always ask where to save
          "general.autoScroll" = true;
          "sidebar.verticalTabs" = true;
          "sidebar.revamp" = true;
          "browser.translations.automaticallyPopup" = false;
          "browser.tabs.groups.smart.userEnabled" = false;
          "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
          "browser.newtabpage.activity-stream.feeds.snippets" = false;
          "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
          "browser.aboutConfig.showWarning" = false;

          # --- Media ---
          "media.eme.enabled" = true; # DRM (Widevine)

          # --- Performance ---
          "browser.sessionstore.interval" = 15000;

          # Auto-enable extensions installed via home-manager (no manual approval prompt)
          "extensions.autoDisableScopes" = 0;
        };

        # Catppuccin Mocha — Firefox chrome theme
        # To use a remote source instead, set this to a path:
        #   userChrome = pkgs.fetchurl {
        #     url = "https://raw.githubusercontent.com/.../userChrome.css";
        #     hash = "sha256-...";
        #   };
        userChrome = ''
          /* Catppuccin Mocha — toolbar + sidebar colors */
          :root {
            --lwt-accent-color: #1e1e2e;
            --lwt-text-color: #cdd6f4;
            --lwt-toolbar-field-color: #313244;
            --lwt-toolbar-field-text-color: #cdd6f4;
            --lwt-selected-tab-background-color: #313244;
            --lwt-sidebar-background-color: #11111b;
            --lwt-sidebar-text-color: #cdd6f4;
          }
        '';
      };
    };
  };
}
