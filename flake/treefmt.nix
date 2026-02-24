{
  inputs,
  ...
}:
{
  imports = [ inputs.treefmt-nix.flakeModule ];
  perSystem = {
    treefmt.programs = {
      keep-sorted.enable = true;
      nixfmt.enable = true;
    };
  };
}
