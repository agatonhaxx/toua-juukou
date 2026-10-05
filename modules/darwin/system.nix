{ config, ... }:
{
  system = {
    primaryUser = config.toua.primaryUser;
    stateVersion = 5;
  };
}
