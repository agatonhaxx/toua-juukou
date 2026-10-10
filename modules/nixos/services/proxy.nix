{
  config,
  lib,
  ...
}:
let
  inherit (import ../../shared/lib.nix { inherit lib; }) mkWebService;

  web = mkWebService {
    inherit config;
    name = "proxy";
  };

  # Services this host only fronts: they run on another machine, so their
  # `enable` stays false here and only `domain` and `proxy` are set. acme, nginx,
  # tailscale and borgbackup declare option sets of their own and have no
  # `proxy`, which is what the `or` covers.
  proxied = lib.filterAttrs (_: service: (service.proxy or null) != null) config.toua.services;

  # Tailscale's CGNAT range and the IPv6 range it hands out. A tailnet-only
  # vhost cannot bind the tailscale address instead — it is assigned at login —
  # so it listens everywhere and refuses every other source.
  tailnetOnly = ''
    allow 100.64.0.0/10;
    allow fd7a:115c:a1e0::/48;
    deny all;
  '';

  vhost =
    service:
    let
      proxy = service.proxy;
    in
    {
      useACMEHost = service.domain;
      forceSSL = true;
      extraConfig = lib.optionalString (proxy.access == "tailnet") tailnetOnly;

      # `proxy_pass` with a variable in it defers the name lookup to request
      # time. nginx otherwise resolves it once, while loading its config, and
      # refuses to start when the backend name does not answer yet — which takes
      # down every vhost on the host, the control server included, so the backend
      # can never enrol through the very name that would have resolved it.
      locations."/" = {
        proxyPass = "http://$backend";
        proxyWebsockets = proxy.websockets;

        extraConfig = lib.concatLines (
          [
            # A variable `proxy_pass` needs a resolver of its own; nginx does not
            # consult /etc/resolv.conf for it. 100.100.100.100 is tailscaled's
            # MagicDNS stub, the one resolver that knows the tailnet's names.
            "resolver 100.100.100.100 valid=30s;"

            # A rewrite-phase directive, so it holds a value before `proxy_pass`
            # runs, whatever order they appear in here.
            "set $backend \"${proxy.host}:${toString service.port}\";"
          ]
          ++ lib.optional (proxy.maxBodySize != null) "client_max_body_size ${proxy.maxBodySize};"
          ++ lib.optional (proxy.extraConfig != "") proxy.extraConfig
        );
      };
    };
in
{
  # Whole option values, rather than one definition per vhost: the module system
  # pushes `mkIf` and `mkMerge` contents down before `config` exists, so a
  # definition whose *shape* is built from `config` — a `mkMerge` over `proxied` —
  # recurses. Values are free to read it, since they are forced only when the
  # option behind them is merged.
  config = lib.mkIf web.dependenciesEnabled {
    assertions =
      web.assertions
      ++ lib.mapAttrsToList (name: service: {
        assertion = service.domain != "";
        message = "toua.services.${name}.proxy needs toua.services.${name}.domain on the host that fronts it.";
      }) proxied;

    # Every vhost gets its own certificate, issued through the Cloudflare DNS
    # challenge, and the fronting nginx serves it under the service's name.
    security.acme.certs = lib.mapAttrs' (
      _: service: lib.nameValuePair service.domain web.certificate
    ) proxied;

    services.nginx.virtualHosts = lib.mapAttrs' (
      _: service: lib.nameValuePair service.domain (vhost service)
    ) proxied;

    # The deferred lookup above means nginx no longer fails when the tailnet is
    # not up yet, so this ordering is only about the window: with it the vhosts
    # answer as soon as the node is on the tailnet rather than 502-ing until it
    # is. `tailscaled.service` is the daemon; `tailscaled-autoconnect.service` is
    # the `tailscale up` behind it, which nixpkgs documents as the unit to order
    # after, and which is absent when the node does not enrol from a key.
    systemd.services.nginx = lib.mkIf (proxied != { } && config.toua.services.tailscale.enable) {
      wants = [ "tailscaled.service" ];
      after = [
        "tailscaled.service"
        "tailscaled-autoconnect.service"
      ];
    };
  };
}
