{
  sops = {
    # sops-nix derives age from the SSH host key, so its public key (via
    # ssh-to-age) only has to be a recipient in ../../.sops.yaml.
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    # Don't load SSH keys from the GNUPGHOME agent
    gnupg.sshKeyPaths = [ ];
  };
}
