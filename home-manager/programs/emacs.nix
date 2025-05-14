{ pkgs, ... }:

{
  enable = true;
  package =
    (pkgs.emacsPackagesFor (
      pkgs.emacs.override {
        withNativeCompilation = false;
      }
    )).emacsWithPackages
      (
        epkgs: with epkgs; [
          vterm
          treesit-grammars.with-all-grammars
        ]
      );
}
