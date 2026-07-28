{
  common = [
    (import ./go.nix)
  ];
  linux = [ ];
  darwin = [
    (import ./crates-io-static.nix)
  ];
}
