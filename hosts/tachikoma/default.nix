{ inputs, ... }:
{
  imports = [
    # TODO add steam deck stuff
    ../../user
  ];

  toua = {
    profiles.headless.enable = true;
    users.eek.homeModule = ../../user/eek;
  };
}
