{
  inputs,
  system,
  ...
}:
let
  t3codePackages = import ../../pkgs/t3code.nix { inherit inputs system; };
in
{
  home.packages = [
    t3codePackages.t3code
    t3codePackages.t3code-desktop
  ];
}
