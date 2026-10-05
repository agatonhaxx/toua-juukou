{
  sops = {
    # sops-nix auto-converts the SSH host ed25519 key to age, so no separate
    # key provisioning is needed. The matching public key (via ssh-to-age)
    # must be listed as a recipient in ../../.sops.yaml.
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    # Don't load SSH keys from the GNUPGHOME agent
    gnupg.sshKeyPaths = [ ];
  };
}
