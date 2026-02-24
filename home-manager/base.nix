{
  pkgs,
  username,
  ...
}:
{
  home = {
    inherit username;

    stateVersion = "24.05";

    sessionPath = [
      "$HOME/.local/bin"
      "$HOME/.elan/bin"
    ]
    ++ (
      if pkgs.stdenv.isDarwin then
        [
          "$HOME/.volta/bin"
          "$HOME/.anyenv/bin"
        ]
      else
        [ ]
    );

    language.base = "en_US.UTF-8";
};

  programs.home-manager.enable = true;
}
