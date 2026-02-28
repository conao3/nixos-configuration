{ ... }:
{
  programs.zsh = {
    enable = true;
    profileExtra = ''
      which /opt/homebrew/bin/brew >/dev/null 2>&1 && eval "$(/opt/homebrew/bin/brew shellenv)"
      which anyenv >/dev/null 2>&1 && eval "$(anyenv init -)"
    '';
    initContent = ''
      [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
      bindkey -e
      function ghq() {
        if [ "$1" = "cd" ]; then
          shift
          local repo=$(command ghq list | fzf --query "$*")
          if [ -n "$repo" ]; then
            cd "$(command ghq root)/$repo"
          fi
        else
          command ghq "$@"
        fi
      }
    '';
    envExtra = ''
      [[ -s "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
    '';
  };
}
