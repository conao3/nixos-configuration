{ pkgs, ... }:
{
  programs = {
    # https://nix-community.github.io/home-manager/options.xhtml
    alacritty.enable = true;
    awscli.enable = true;
    bat.enable = true;
    eza.enable = true;
    fzf = {
      enable = true;
      historyWidget.command = "";
    };
    gh = {
      enable = true;
      extensions = [ pkgs.gh-poi ];
    };
    go.enable = true;
    gpg.enable = true;
    htop.enable = true;
    java.enable = true;
    jq.enable = true;
    lsd.enable = true;
    ripgrep.enable = true;
    tmux = {
      enable = true;
      package =
        if pkgs.stdenv.hostPlatform.isLinux then
          pkgs.callPackage ../../pkgs/tmux-with-server.nix { }
        else
          pkgs.tmux;
      prefix = "C-q";
      keyMode = "emacs";
      extraConfig = ''
        set -s copy-command '${
          if pkgs.stdenv.hostPlatform.isDarwin then "pbcopy" else "xsel -i --clipboard"
        }'
        set -g mouse on
        bind -n WheelUpPane if -F "#{mouse_any_flag}" "send-keys -M" "copy-mode -e"
        bind -n WheelDownPane select-pane \; send-keys -M
      '';
    };
    vim.enable = true;
    vscode.enable = !pkgs.stdenv.hostPlatform.isDarwin;
    zed-editor.enable = !pkgs.stdenv.hostPlatform.isDarwin;
  };
}
