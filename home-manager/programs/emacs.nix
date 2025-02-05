{ pkgs, ... }:

{
  enable = true;
  package = (pkgs.emacsPackagesFor pkgs.emacs-git).emacsWithPackages (
    epkgs: with epkgs; [
      vterm
      treesit-grammars.with-all-grammars
    ]
  );
}
