{ pkgs, ... }:
{
  programs.emacs = {
    enable = true;
    package =
      (pkgs.emacsPackagesFor (
        pkgs.emacs.override {
          withNativeCompilation = false;
          withTreeSitter = true;
        }
      )).emacsWithPackages
        (
          epkgs:
          (with epkgs; [
            vterm
            (treesit-grammars.with-grammars (
              grammars:
              builtins.filter (g: !(builtins.elem g.pname [ "tree-sitter-razor" ])) (builtins.attrValues grammars)
            ))
          ])
          ++ [
            pkgs.gcc
            pkgs.nodejs
          ]
        );
    extraConfig = ''
      (push "${pkgs.gcc}/bin" exec-path)
      (push "${pkgs.nodejs}/bin" exec-path)

      (defun conao-disable-fcitx5 (&rest _)
        (when (file-executable-p "${pkgs.fcitx5}/bin/fcitx5-remote")
          (call-process "${pkgs.fcitx5}/bin/fcitx5-remote" nil nil nil "-c")))

      (add-hook 'focus-in-hook #'conao-disable-fcitx5)
      (add-hook 'after-make-frame-functions #'conao-disable-fcitx5)
      (conao-disable-fcitx5)
    '';
  };

  services.emacs = {
    enable = true;
    defaultEditor = true;
  };

  home.shellAliases = {
    e = "$EDITOR";
  };

  programs.git.ignores = [
    "*~"
    ".#*"
    "\\#*"
    "*_flymake.*"
    "flycheck_*"
    ".dir-locals-2.el"
  ];
}
