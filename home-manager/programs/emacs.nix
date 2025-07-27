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
          treesit-grammars.with-all-grammars
        ]
      );
  extraConfig = ''
    (setq exec-path (cons "${pkgs.gcc}/bin" exec-path))
  '';
}
