{
  enable = true;
  profileExtra = ''
    . "$HOME/.cargo/env"
    eval "$(anyenv init -)"
    [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
  '';
}
