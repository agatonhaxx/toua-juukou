{
  config,
  lib,
  ...
}:
{
  options.toua.services.nginx.enable = lib.mkEnableOption "the nginx service";

  config = lib.mkIf config.toua.services.nginx.enable {
    assertions = [
      {
        assertion = config.toua.domain != "";
        message = "toua.services.nginx.enable needs toua.domain.";
      }
    ];

    services.nginx = {
      enable = true;

      recommendedTlsSettings = true;
      recommendedProxySettings = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
    };

    # 443 carries the traffic; 80 carries only the redirect that `forceSSL`
    # writes on each vhost.
    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
  };
}
