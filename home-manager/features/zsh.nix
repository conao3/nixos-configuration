{ ... }:
{
  programs.zsh = {
    enable = true;
    profileExtra = ''
      which /opt/homebrew/bin/brew >/dev/null 2>&1 && eval "$(/opt/homebrew/bin/brew shellenv)"
      which anyenv >/dev/null 2>&1 && eval "$(anyenv init -)"
    '';
    initContent = ''
      if command -v tmux &> /dev/null && [ -z "$TMUX" ]; then
        n=0
        while tmux has-session -t "$(printf 'tmp-%03d' "$n")" 2>/dev/null; do
          n=$((n + 1))
        done
        exec tmux new-session -s "$(printf 'tmp-%03d' "$n")"
      fi
      [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
      bindkey -e
      function ghq() {
        if [ "$1" = "cd" ]; then
          shift
          local repo=$(command ghq list | fzf --query "conao3/$*")
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
