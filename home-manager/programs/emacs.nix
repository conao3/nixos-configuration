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
  '';
}
