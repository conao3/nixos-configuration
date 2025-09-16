{
  enable = true;
  profileExtra = ''
    which /opt/homebrew/bin/brew >/dev/null 2>&1 && eval "$(/opt/homebrew/bin/brew shellenv)"
    which anyenv >/dev/null 2>&1 && eval "$(anyenv init -)"
  '';
  initContent = ''
    [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
  '';
  envExtra = ''
    [[ -s "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
  '';
}
