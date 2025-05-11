{
  enable = true;
  profileExtra = ''
    eval "$(/opt/homebrew/bin/brew shellenv)"
    eval "$(anyenv init -)"
  '';
  initContent = ''
    [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
  '';
  envExtra = ''
    [[ -s "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
  '';
}
