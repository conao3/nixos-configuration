{ ... }:
{
  programs = {
    # https://nix-community.github.io/home-manager/options.xhtml
    # keep-sorted start
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
    tmux = {
      enable = true;
      prefix = "C-q";
    };
    vim.enable = true;
    vscode.enable = true;
    zed-editor.enable = true;
    # keep-sorted end
  };
}
