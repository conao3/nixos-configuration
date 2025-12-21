{ pkgs, ... }:

{
  enable = true;
  package =
    (pkgs.emacsPackagesFor (
      pkgs.emacs.override {
        withNativeCompilation = false;
        withTreeSitter = true;
      }
    )).emacsWithPackages
      (
        epkgs: with epkgs; [
          vterm
          (treesit-grammars.with-grammars (
            grammars:
            builtins.filter (g: !(builtins.elem g.pname [ "tree-sitter-razor" ])) (builtins.attrValues grammars)
          ))
        ]
      );
  extraConfig = ''
    (setq exec-path (cons "${pkgs.gcc}/bin" exec-path))
  '';
}
