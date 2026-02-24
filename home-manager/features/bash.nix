{ ... }:
{
  programs.bash = {
    enable = true;
    profileExtra = ''
      [[ -s "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
      which anyenv >/dev/null 2>&1 && eval "$(anyenv init -)"
      [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
    '';
  };
}
