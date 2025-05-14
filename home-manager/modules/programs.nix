{
  pkgs,
  ...
}:
{
  programs = {
    # Enable home-manager itself
    home-manager.enable = true;

    # Core CLI programs with basic configuration
    alacritty.enable = true;
    awscli.enable = true;
    bat.enable = true;
    eza.enable = true;
    fzf.enable = true;
    gh.enable = true;
    go.enable = true;
    gpg.enable = true;
    htop.enable = true;
    java.enable = true;
    jq.enable = true;
    lsd.enable = true;
    ripgrep.enable = true;
    tmux.enable = true;
    vim.enable = true;
    vscode.enable = false; # Currently disabled due to unfree license

    # Programs with custom configurations
    atuin = import ../programs/atuin.nix;
    bash = import ../programs/bash.nix;
    direnv = import ../programs/direnv.nix;
    emacs = import ../programs/emacs.nix (pkgs);
    git = import ../programs/git.nix;
    neovim = import ../programs/neovim.nix;
    zsh = import ../programs/zsh.nix;
  };
}
