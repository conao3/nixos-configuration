{
  enable = true;
  profileExtra = ''
    eval "$(/opt/homebrew/bin/brew shellenv)"
    eval "$(anyenv init -)"
  '';
  initExtra = ''
    [[ -s "/opt/homebrew/opt/sdkman-cli/libexec/bin/sdkman-init.sh" ]] && source "/opt/homebrew/opt/sdkman-cli/libexec/bin/sdkman-init.sh"
  '';
  envExtra = ''
    . "$HOME/.cargo/env"
  '';
}
