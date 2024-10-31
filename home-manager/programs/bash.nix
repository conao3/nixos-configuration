{
  enable = true;
  profileExtra = ''
    . "$HOME/.cargo/env"
    eval "$(anyenv init -)"
    [[ -s "/opt/homebrew/opt/sdkman-cli/libexec/bin/sdkman-init.sh" ]] && source "/opt/homebrew/opt/sdkman-cli/libexec/bin/sdkman-init.sh"
  '';
}
